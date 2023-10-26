require 'json'
require 'pry'
require 'date'
require 'rest-client'
require 'aws-sdk-s3'
require 'aws-sdk-glue'
require 'concurrent'
require 'forwardable'

require_relative 'athena-manager'
require_relative 'lib/ticketsauce_api.rb'

# RestClient.log = STDOUT

require 'dotenv'
Dotenv.load('../.env')

Thread.abort_on_exception = true

class TicketWarehouse
  extend Forwardable
  def_delegators :@ticketsauce_api, :access_token, :authenticate!, :fetch_events
  def_delegators :@ticketsauce_api, :fetch_orders, :fetch_order_details, :fetch_checkin_ids

  class APIError < StandardError
  end
  class APINoDataError < StandardError
  end

  def initialize(client_id:, client_secret:)
    @ticketsauce_api = TicketsauceApi.new(client_id: client_id, client_secret: client_secret)
    @s3 = Aws::S3::Resource.new(region: 'us-east-1')
    @athena = AthenaManager.new
    @bucket_name = ENV['BUCKET_NAME']
    @tables = [
      'ticket_warehouse_events',
      'ticket_warehouse_orders',
      'ticket_warehouse_tickets',
      'ticket_warehouse_checkin_ids'
    ]
    @existing_athena_partitions = nil
  end

  def archive_events(time_range: nil, num_threads: 4)
    puts "Archiving events for time range: #{time_range}"

    events = fetch_events_by_time_range(time_range: time_range)

    puts "Archiving #{events.length} events."
    puts "Thread pool size: #{num_threads}"

    pool = Concurrent::ThreadPoolExecutor.new(
      min_threads: num_threads,
      max_threads: num_threads,
      max_queue: 0,
      fallback_policy: :caller_runs
    )

    stop_due_to_error = Concurrent::AtomicBoolean.new(false)
    events.each do |event|
      # pool.post do
        begin
          # Archive the event.
          upload_to_s3(
            event: event,
            data: [event],
            table_name: 'ticket_warehouse_events'
          )

          # Archive orders for the event.
          begin
            orders = fetch_orders(event: event)
            archived_tickets_count = 0
            orders_with_order_details =
              orders.map do |order|
                fetch_order_details(order: order)
              end
            upload_to_s3(
              event: event,
              data: orders_with_order_details,
              table_name: 'ticket_warehouse_orders'
            )

          rescue APINoDataError => error
            puts "No orders for event #{event['Event']['name']}"
            orders_with_order_details = []
          rescue => error
            puts "Error archiving orders for event #{event['Event']['name']}: #{error.message}"
            puts error.backtrace.join("\n")
            stop_due_to_error.make_true
          end

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
            table_name: 'ticket_warehouse_tickets'
          )
          
          puts "Archived #{orders.count} orders with #{tickets_for_orders.count} tickets for event #{event['Event']['name']}"

          # Archive checkin IDs for the event.
          checkin_ids = fetch_checkin_ids(event: event)
          upload_to_s3(
            event: event,
            # The API gives us just a list of checkin IDs, not JSON data.
            # So, transform it.  Give it a column name: 'ticket_id'.
            data: checkin_ids.map{|id| {'ticket_id' => id} },
            table_name: 'ticket_warehouse_checkin_ids'
          )

          puts "Archived #{checkin_ids.count} checkin IDs for event #{event['Event']['name']}"

          # Update the Athena partitions if necessary.
          puts 'Existing partition count per table (first table): ' +
            existing_athena_partitions.count.to_s
          updated_partitions = false
          partition = athena_partitions(event: event).first
          raw_partition_name =
            partition.match(%r{venue=(?<venue>[^/]+)/year=(?<year>\d+)/month=(?<month>\w+)/day=(?<day>\d+)/}) do |match|
              "venue=#{match[:venue]}/year=#{match[:year]}/month=#{match[:month]}/day=#{match[:day]}"
            end
          puts "Existing partitions: #{existing_athena_partitions}" if ENV['DEBUG']
          puts "Partition: #{partition}" if ENV['DEBUG']
          puts "Raw partition name: #{raw_partition_name}" if ENV['DEBUG']
          unless existing_athena_partitions.include?(raw_partition_name)
            puts "Creating Athena partition in all four tables: #{raw_partition_name}"
            @tables.each do |table_name|
              query_string = partition.match(%r{venue=(?<venue>[^/]+)/year=(?<year>\d+)/month=(?<month>\w+)/day=(?<day>\d+)/}) do |m|
                "ALTER TABLE #{table_name} ADD PARTITION (venue = '#{m[:venue]}', year = '#{m[:year]}', month = '#{m[:month]}', day = '#{m[:day]}');"
              end
              puts "Query string: #{query_string}" if ENV['DEBUG']
              @athena.start_query(query_string: query_string)
            end
            updated_partitions = true
          end
          puts "Updated partition count: #{existing_athena_partitions(memoize:false).count}" if updated_partitions
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
            exit(1)
          end
        end
      # end
    end

    pool.shutdown
    puts "Waiting for all threads to complete..."
    pool.wait_for_termination

    puts "Archived #{events.length} events."

  end

  def generate_file_path(event:, table_name:)
    puts "Generating file path for event #{event['Event']['name']} and table #{table_name}" if ENV['DEBUG']
    location = url_safe_name(event['Event']['organization_name'])
    start = DateTime.parse(event['Event']['start'])
    
    year = start.year.to_s
    month_name = Date::MONTHNAMES[start.month]
    day_number = start.day.to_s.rjust(2, '0')
    event_name = url_safe_name(event['Event']['name'])
    
    "#{table_name}/venue=#{location}/year=#{year}/month=#{month_name}/day=#{day_number}/"
  end

  def fetch_events_by_time_range(time_range: nil)
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
    events
  end

  def athena_partitions(event:)
    @tables.map do |table_name|
      generate_file_path(event:event, table_name:table_name)
    end.tap do |partitions|
      partitions.each do |partition|
        raw_partition_name = partition.match(/^[^\/]+\/(.*)\//)[1]
      end
    end
  end

  # We need to get the existing partitions for a table so that we can
  # avoid re-creating them.
  def existing_athena_partitions(memoize:true)
    if memoize == false
      @existing_athena_partitions = nil
    end

    @existing_athena_partitions ||=
      # WARNING: We assume that the partitions are the same for all tables.
      @athena.start_query(query_string: <<-QUERY
          SHOW PARTITIONS #{@tables.first};
        QUERY
      ) || []
  end

  private

  def url_safe_name(name)
    name.gsub(/[^0-9A-Za-z]/, '-').squeeze('-').downcase
  end

  def to_ndjson(data)
    data.map { |item| JSON.generate(item) }.join("\n")
  end

  def upload_to_s3(event:, data:, table_name:)
    puts "Uploading #{data.length} records to #{table_name} on S3..." if ENV['DEBUG']

    event_name = url_safe_name(event['Event']['name'])
    file_path = generate_file_path(event:event, table_name:table_name) +
      "#{url_safe_name(event_name)}.json"

    puts "Archiving #{table_name} for event #{event_name} to S3 at file path: #{file_path}"
    
    s3_object = @s3.bucket(@bucket_name).object(file_path)

    s3_object.put(body: to_ndjson(data))
  end

end
