require 'json'
require 'pry'
require 'date'
require 'rest-client'
require 'aws-sdk-s3'
require 'aws-sdk-athena'

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
  
  def fetch_events(organization_id: nil, start_before: nil, start_after: nil)
    params = {}
    params[:organization_id] = organization_id if organization_id
    params[:start_before] = start_before if start_before
    params[:start_after] = start_after if start_after
    
    query_string = params.empty? ? '' : '?' + URI.encode_www_form(params)
    
    url = "https://api.ticketsauce.com/v2/events#{query_string}"
    response = RestClient.get(url, { Authorization: "Bearer #{@access_token}" })
    JSON.parse(response.body).tap do |orders|
      raise APINoDataError.new(orders['error']) if orders.is_a?(Hash) && orders['error'].eql?('no_data')
      raise APIError.new(orders['error']) if orders.is_a?(Hash) && orders['error']
    end
  end

  def fetch_orders(event:)
    event_id = event['Event']['id']
    response = RestClient.get("https://api.ticketsauce.com/v2/orders/#{event_id}", { Authorization: "Bearer #{@access_token}" })
    JSON.parse(response.body).tap do |orders|
      raise APINoDataError.new(orders['error']) if orders.is_a?(Hash) && orders['error'].eql?('no_data')
      raise APIError.new(orders['error']) if orders.is_a?(Hash) && orders['error']
    end
  end

  def fetch_order_details(order:)
    order_id = order['Order']['id']
    response = RestClient.get("https://api.ticketsauce.com/v2/order/#{order_id}", { Authorization: "Bearer #{@access_token}" })
    JSON.parse(response.body)
  end

  def fetch_checkin_ids(event:)
    event_id = event['Event']['id']
    response = RestClient.get("https://api.ticketsauce.com/v2/tickets/checkin_ids/#{event_id}", { Authorization: "Bearer #{@access_token}" })
    JSON.parse(response.body)
  end

  def archive_events(time_range:nil)
    puts "Archiving events for time range: #{time_range}"

    puts "Ensuring Athena tables are up to date"
    @athena.start_query(query_name:'CreateDatabase')
    @athena.start_query(query_name:'EventsTableDefinition')
    @athena.start_query(query_name:'OrdersTableDefinition')
    @athena.start_query(query_name:'TicketsTableDefinition')

    start_before = nil
    start_after = nil
    case time_range
    when :current
      start_after =
        # Now minus one day.
        (Time.now - 86400).strftime('%Y-%m-%d')
      start_before =
        # Now plus two days.
        (Time.now + 86400 * 2).strftime('%Y-%m-%d')
    when :upcoming
      start_after =
        # Now minus one day.
        (Time.now - 86400).strftime('%Y-%m-%d')
    end

    events = fetch_events(
      start_before: start_before,
      start_after: start_after)
    events.each do |event|
      upload_event_to_s3(event:event)

      begin
        orders = fetch_orders(event: event)
        orders.each do |order|
          order_details = fetch_order_details(order: order)
          upload_order_to_s3(event:event, order:order_details)

          order_details['Ticket'].each do |ticket|
            upload_ticket_to_s3(event:event, ticket:ticket)
          end
          puts "Archived #{order_details['Ticket'].length} tickets for order #{order['Order']['id']}"
        end
        puts "Archived #{orders.length} orders for event #{event['Event']['name']}"
      rescue APINoDataError => error
        puts "No orders for event #{event['Event']['name']}"
      end
    end

    %w[events orders tickets].each do |table|
      @athena.repair_table(table)
    end
  end
  
  def generate_file_path(event:, table_name:)
    location = url_safe_name(event['Event']['location'])
    event_name = url_safe_name(event['Event']['name'])
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

  def upload_event_to_s3(event:)
    file_path = generate_file_path(event:event, table_name:'events') +
      "#{event['Event']['name']}.json"
    puts "Archiving event to S3 at file path: #{file_path}" +
      "\n#{JSON.pretty_generate(event)}"
    bucket_name = ENV['BUCKET_NAME']
    
    s3_object = @s3.bucket(bucket_name).object(file_path)
    
    s3_object.put(body: event.to_json)
  end

  def upload_order_to_s3(event:, order:)
    file_path = generate_file_path(event:event, table_name:'orders') +
      "#{order['Order']['id']}.json"
    bucket_name = ENV['BUCKET_NAME']
    
    s3_object = @s3.bucket(bucket_name).object(file_path)
    
    s3_object.put(body: order.to_json)
  end

  def upload_ticket_to_s3(event:, ticket:)
    file_path = generate_file_path(event:event, table_name:'tickets') +
      "#{ticket['id']}.json"
    bucket_name = ENV['BUCKET_NAME']
    
    s3_object = @s3.bucket(bucket_name).object(file_path)
    
    s3_object.put(body: ticket.to_json)
  end

end
