require 'json'
require 'pry'
require 'date'
require 'rest-client'
require 'aws-sdk-s3'
require 'aws-sdk-glue'
require 'concurrent'

require_relative 'athena-manager'

# RestClient.log = STDOUT

require 'dotenv'
Dotenv.load('../.env')

class TicketWarehouse
  attr_reader :access_token

  def initialize(client_id:, client_secret:)
    @client_id = client_id
    @client_secret = client_secret
    @access_token = nil
    @s3 = Aws::S3::Resource.new(region: 'us-east-1')
    @athena = AthenaManager.new
    @bucket_name = ENV['BUCKET_NAME']
  end

  def authenticate!
    response = RestClient.post('https://api.ticketsauce.com/v2/oauth/token', {
      grant_type: 'client_credentials',
      client_id: @client_id,
      client_secret: @client_secret
    })
    @access_token = JSON.parse(response.body)['access_token']
  end

  class APIError < StandardError
  end
  class APINoDataError < StandardError
  end

  def fetch_api_data(endpoint_url)
    response = RestClient.get(endpoint_url, { Authorization: "Bearer #{@access_token}" })
    JSON.parse(response.body).tap do |data|
      raise APINoDataError.new(data['error']) if data.is_a?(Hash) && data['error'].eql?('no_data')
      raise APIError.new(data['error']) if data.is_a?(Hash) && data['error']
    end
  end

  def fetch_events(organization_id: nil, start_before: nil, start_after: nil)
    params = {}
    params[:organization_id] = organization_id if organization_id
    params[:start_before] = start_before if start_before
    params[:start_after] = start_after if start_after
    
    query_string = params.empty? ? '' : '?' + URI.encode_www_form(params)
    
    fetch_api_data("https://api.ticketsauce.com/v2/events#{query_string}")
  end

  def fetch_orders(event:)
    event_id = event['Event']['id']
    fetch_api_data("https://api.ticketsauce.com/v2/orders/#{event_id}")
  end

  def fetch_order_details(order:)
    order_id = order['Order']['id']
    fetch_api_data("https://api.ticketsauce.com/v2/order/#{order_id}")
  end

  def fetch_checkin_ids(event:)
    event_id = event['Event']['id']
    fetch_api_data("https://api.ticketsauce.com/v2/tickets/checkin_ids/#{event_id}")
  end

  def archive_events(time_range: nil, num_threads: 4)
    puts "Archiving events for time range: #{time_range}"

    start_before = nil
    start_after = nil
    case time_range
    when 'current'
      start_after =
        # Now minus one day.
        (Time.now - 86400).strftime('%Y-%m-%d')
      start_before =
        # Now plus two days.
        (Time.now + 86400 * 2).strftime('%Y-%m-%d')
    when 'upcoming'
      start_after =
        # Now minus one day.
        (Time.now - 86400).strftime('%Y-%m-%d')
    when 'recent'
      start_after =
        # Now minus 30 days.
        (Time.now - 86400 * 30).strftime('%Y-%m-%d')
      start_before =
        # Now minus one day.
        (Time.now - 86400).strftime('%Y-%m-%d')
    end

    events = fetch_events(
      start_before: start_before,
      start_after: start_after)

    puts "Archiving #{events.length} events."

    num_threads = 4
    pool = Concurrent::ThreadPoolExecutor.new(
      min_threads: num_threads,
      max_threads: num_threads,
      max_queue: 0,
      fallback_policy: :caller_runs
    )

    stop_due_to_error = Concurrent::AtomicBoolean.new(false)
    events.each do |event|
      pool.post do
        begin
          # Archive the event.
          upload_to_s3(
            event: event,
            data: [event],
            table_name: 'events'
          )

          # Archive orders for the event.
          orders = fetch_orders(event: event)
          archived_tickets_count = 0
          orders_with_order_details =
            orders.map do |order|
              fetch_order_details(order: order)
            end
          upload_to_s3(
            event: event,
            data: orders_with_order_details,
            table_name: 'orders'
          )

          # Archive tickets for the orders for the event.
          tickets_for_orders =
            orders_with_order_details.map do |order|
              order['Ticket'].map do |ticket|
                ticket.merge(
                  'order_id' => order['Order']['id']
                )
              end
            end.flatten.map do |ticket|
                ticket.merge(
                  'event_id' => event['Event']['id']
                )
              end
          upload_to_s3(
            event: event,
            data: tickets_for_orders,
            table_name: 'tickets'
          )
          
          puts "Archived #{orders.count} orders with #{tickets_for_orders.count} tickets for event #{event['Event']['name']}"

          # Archive checkin IDs for the event.
          checkin_ids = fetch_checkin_ids(event: event)
          upload_to_s3(
            event: event,
            # The API gives us just a list of checkin IDs, not JSON data.
            # So, transform it.  Give it a column name: 'ticket_id'.
            data: checkin_ids.map{|id| {'ticket_id' => id} },
            table_name: 'checkin_ids'
          )

          puts "Archived #{checkin_ids.count} checkin IDs for event #{event['Event']['name']}"
        rescue APINoDataError => error
          puts "No orders for event #{event['Event']['name']}"
        rescue => error
          puts "Error archiving event #{event['Event']['name']}: #{error.message}"
          puts error.backtrace.join("\n")
          stop_due_to_error.make_true
        ensure
          if stop_due_to_error.true?
            puts "Stopping due to error..."
            pool.kill
          end
        end
      end
    end

    pool.shutdown
    puts "Waiting for all threads to complete..."
    pool.wait_for_termination

    puts "Archived #{events.length} events."

    # Trigger the Glue crawlers to update the Athena tables.
    glue_client = Aws::Glue::Client.new(region: 'us-east-1')

    [
      'ticket-warehouse-events-crawler',
      'ticket-warehouse-orders-crawler',
      'ticket-warehouse-tickets-crawler',
      'ticket-warehouse-checkin-ids-crawler'
    ].each do |crawler_name|
      glue_client.start_crawler(name: crawler_name)
      puts "Started the Glue crawler: #{crawler_name}"
    end
  end

  def generate_file_path(event:, table_name:)
    location = url_safe_name(event['Event']['location'])
    start = DateTime.parse(event['Event']['start'])
    
    year = start.year.to_s
    month_name = Date::MONTHNAMES[start.month]
    day_number = start.day.to_s.rjust(2, '0')
    
    "#{table_name}/venue=#{location}/year=#{year}/month=#{month_name}/day=#{day_number}/"
  end

  private

  def url_safe_name(name)
    name.gsub(/[^0-9A-Za-z]/, '-').squeeze('-').downcase
  end

  def to_ndjson(data)
    data.map { |item| JSON.generate(item) }.join("\n")
  end

  def upload_to_s3(event:, data:, table_name:)
    event_name = url_safe_name(event['Event']['name'])
    file_path = generate_file_path(event:event, table_name:table_name) +
      "#{url_safe_name(event_name)}.json"
    puts "Archiving #{table_name} for event #{event_name} to S3 at file path: #{file_path}"
    
    s3_object = @s3.bucket(@bucket_name).object(file_path)

    s3_object.put(body: to_ndjson(data))
  end

end
