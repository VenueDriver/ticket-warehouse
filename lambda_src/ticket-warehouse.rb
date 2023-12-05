require 'json'
require 'pry'
require 'date'
require 'rest-client'
require 'aws-sdk-s3'
require 'aws-sdk-glue'
require 'concurrent'
require 'forwardable'
require 'bigdecimal'
require 'bigdecimal/util'

require_relative 'athena-manager'
require_relative 'lib/ticketsauce_api.rb'
require_relative 'lib/api_errors.rb'
require_relative 'lib/s3_uploader.rb'
require_relative 'lib/pool.rb'
require_relative 'lib/stripe.rb'

# RestClient.log = STDOUT

require 'dotenv'
Dotenv.load('../.env')

Thread.abort_on_exception = true

class TicketWarehouse
  extend Forwardable
  def_delegators :@ticketsauce_api, :authenticate!, :fetch_events
  def_delegators :@ticketsauce_api, :fetch_orders, :fetch_order_details, :fetch_checkin_ids
  attr_accessor :s3_uploader, :skip_athena_partitioning

  def initialize(client_id:, client_secret:)
    @ticketsauce_api = TicketsauceApi.new(client_id: client_id, client_secret: client_secret)
    @s3 = Aws::S3::Resource.new(region: 'us-east-1')
    @athena = AthenaManager.new
    @bucket_name = ENV['BUCKET_NAME']
    @tables = [
      'ticket_warehouse_events',
      'ticket_warehouse_orders',
      'ticket_warehouse_tickets',
      'ticket_warehouse_ticket_types',
      'ticket_warehouse_checkin_ids',
      'ticket_warehouse_stripe_charges'
    ]
    @existing_athena_partitions = nil
    @skip_athena_partitioning = false
    @s3_uploader = S3Uploader.new(@s3, @bucket_name)
    @fee_types = %w[ticketing_fee surcharge let_tax sales_tax venue_fee admin_fee_not_a_gratuity_ gratuity]
  end

  def self.init_default(localize:true, skip_athena_partitioning:false)
    obj = self.new(      
      client_id:     ENV['TICKETSAUCE_CLIENT_ID'],
      client_secret: ENV['TICKETSAUCE_CLIENT_SECRET'])
    obj.tap do |o|
      o.authenticate!
			o.s3_uploader = LocalUploader.new if localize
      o.skip_athena_partitioning = skip_athena_partitioning
    end
  end
	
  def archive_events(time_range: nil, num_threads: 4, enable_threading: false)
    puts "Archiving events for time range: #{time_range}"

    events = fetch_events_by_time_range(time_range: time_range)

    puts "Archiving #{events.length} events."
    
    task_executor = Concurrent.global_immediate_executor
    #to enable threading, replace with : task_executor = :fast
    # OR pass in enable_threading: true
    task_executor = :fast if enable_threading

    tasks = events.map do |event|
      Concurrent::Promises.future_on(task_executor, event) do |event|
        begin
          # Archive the event.
          upload_to_s3(
            event: event,
            data: [event],
            table_name: 'events'
          )

          # Archive orders for the event.
          begin
            # puts "\nArchiving order for event #{event['Event']['name']}"

            orders = fetch_orders(event: event, return_line_item_fees: true)
            archived_tickets_count = 0
            tickets_for_orders = []
            line_item_fees_for_order = {}
            orders_with_order_details =
              orders.map do |order|

                order_details = fetch_order_details(order: order)

                tickets_for_orders << order['Ticket']

                line_item_fees_orig = order['LineItemFees']
                line_items_transformed =
                  ensure_all_fees_present(line_item_fees_orig)

                  # if ENV['DEBUG']
                  #   puts "Line item fees: #{line_item_fees_orig}"
                  #   puts "Transformed:"
                  #   puts line_items_transformed
                  # end
  
                  order_details.merge(
                    'LineItemFees' => line_items_transformed,
                    'Ticket' => order['Ticket'].
                      map do |ticket_sale|

                        # if ENV['DEBUG']
                        #   puts "Ticket sale line item fees: #{ticket_sale['LineItemFees']}"
                        # end

                        # binding.pry unless ticket_sale['LineItemFees'].empty?
                        # binding.pry if ticket_sale['id'].eql? '652d99ca-9a10-4425-865f-47b20ad1e030'

                        ticket_sale_with_line_item_fees =
                          ticket_sale.merge(ensure_all_fees_present(
                            ticket_sale['LineItemFees']))
                        ticket_sale_with_line_item_fees.tap do |ticket_sale|
                          # puts "order _with_order_details: #{ticket_sale}" if ENV['DEBUG']
                        end
                      end
                    )
                end

              # The raw fees confuse Athena, so remove the ['LineItemFees'] key
              # from each item within the order[]'Ticket'] key.
              orders_without_raw_line_item_fees =
                orders_with_order_details.map do |order|
                  order_without_fees = order.dup
                  order_without_fees['Ticket'] = order['Ticket'].map do |ticket|
                    ticket_without_fees = ticket.dup
                    ticket_without_fees.delete('LineItemFees')
                    ticket_without_fees
                  end
                  order_without_fees
                end

              upload_to_s3(
                event: event,
                data: orders_without_raw_line_item_fees,
                table_name: 'orders'
              )

            archive_tickets(event: event, tickets: tickets_for_orders.flatten)
          rescue APINoDataError => error
            puts "No orders for event #{event['Event']['name']}"
            orders = orders_with_order_details = []
          end

          next unless orders_with_order_details.any?

          # Archive tickets for the orders for the event.
          tickets_for_orders =
            orders_with_order_details.map do |order|
              order['Ticket'].map do |ticket|
                ticket.merge(
                  'order_id' => order['Order']['id'],
                  'order_total_paid' => order['Order']['total_paid'],
                  'order_total_face_value' =>
                    sprintf('%.2f',
                      order['Ticket'].sum{|ticket| ticket['price'].to_d })
                )
              end
            end.flatten.map do |ticket|

              # puts "Transformed ticket: #{ticket}" if ENV['DEBUG']

              # binding.pry if ticket['id'].eql? '652d99ca-9a10-4425-865f-47b20ad1e030'

              current_sale_face_value =
                ticket['ticket_type_price'].to_d
              order_total_face_value =
                ticket['order_total_face_value'].to_d

                # binding.pry if ticket['id'].eql? '654d6891-7270-4f51-b608-362b0ad1e02d'

                ticket =
                  ticket.merge(
                    'ticket_type_name' => ticket['TicketType']['name'],
                    'name' => ticket['TicketType']['name'],
                    'event_id' => event['Event']['id']
                  ).merge(ensure_all_fees_present(ticket['LineItemFees']))
                ticket.delete('LineItemFees')
                ticket
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
          
          if !@skip_athena_partitioning
            update_athena_partitions(event: event ) 
          end

        rescue APINoDataError => error
          puts "No orders for event #{event['Event']['name']}"
        end
      end
    end

    puts "preparing to wait for all tasks to comMplete"
    vars = Concurrent::Promises.zip(*tasks).value!
    puts "Archived #{events.length} events."

  end

  def update_athena_partitions(event: )
    # puts 'Existing partition count per table (first table): ' +
    #   existing_athena_partitions.count.to_s
    updated_partitions = false
    partition = athena_partitions(event: event).first
    raw_partition_name =
      partition.match(%r{venue=(?<venue>[^/]+)/year=(?<year>\d+)/month=(?<month>\w+)/day=(?<day>\d+)/}) do |match|
        "venue=#{match[:venue]}/year=#{match[:year]}/month=#{match[:month]}/day=#{match[:day]}"
      end
    # puts "Existing partitions: #{existing_athena_partitions}" if ENV['DEBUG']
    puts "Partition: #{partition}" if ENV['DEBUG']
    # puts "Raw partition name: #{raw_partition_name}" if ENV['DEBUG']
    unless existing_athena_partitions.include?(raw_partition_name)
      puts "Creating Athena partition in all four tables: #{raw_partition_name}"
      @tables.each do |table_name|
        query_string = partition.match(%r{venue=(?<venue>[^/]+)/year=(?<year>\d+)/month=(?<month>\w+)/day=(?<day>\d+)/}) do |m|
          "ALTER TABLE #{table_name} ADD PARTITION (venue = '#{m[:venue]}', year = '#{m[:year]}', month = '#{m[:month]}', day = '#{m[:day]}');"
        end
        # puts "Query string: #{query_string}" if ENV['DEBUG']
        @athena.start_query(query_string: query_string)
      end
      updated_partitions = true
    end
    # puts "Updated partition count: #{existing_athena_partitions(memoize:false).count}" if updated_partitions
  end

  def archive_tickets(event:, tickets:)
    puts "Archiving #{tickets.length} tickets for event #{event['Event']['name']}"

    tickets_data = tickets.map do |ticket|
      {
        'ticket_type_id'       => ticket['ticket_type_id'],
        'ticket_type_price_id' => ticket['ticket_type_price_id'],
        'event_id'             => event['Event']['id'],
        'ticket_type_name'     => ticket['ticket_type_name'],
        'ticket_type_price'    => ticket['ticket_type_price']
      }
    end

    unique_tickets_data =
      tickets_data.uniq{|t| [t['ticket_type_id'], t['ticket_type_price_id']]}

    puts "Archiving #{unique_tickets_data.length} unique tickets for event #{event['Event']['name']}"

    # Upload the ticket details to S3.
    upload_to_s3(
      event: event,
      data: unique_tickets_data,
      table_name: 'ticket_types'
    )

  end

  def generate_file_path(event:, table_name:)
    @s3_uploader.generate_file_path(event:event, table_name:table_name)
  end

  def fetch_events_by_time_range(time_range: nil)
    start_before = nil
    start_after = nil
    case time_range
      when 'test'
        start_after =
          Date.parse('2023-12-31').strftime('%Y-%m-%d')
        start_before =
          Date.parse('2024-01-03').strftime('%Y-%m-%d')
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

    puts "Fetching Ticketsauce events from #{start_after} to #{start_before}"

    fetch_events(
      start_before: start_before,
      start_after: start_after)
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

  def underscore_safe_name(name)
    name.gsub(/[^0-9A-Za-z]/, '_').squeeze('_').downcase
  end

  def to_ndjson(data)
    data.map { |item| JSON.generate(item) }.join("\n")
  end

  def upload_to_s3(event:, data:, table_name:)
    @s3_uploader.upload_to_s3(event: event, data: data, table_name: table_name)
  end

  def ensure_all_fees_present(line_item_fees_orig)
    # Define the order of fee types
    line_item_fees_orig ||= {}
    
    # Transform the keys of the original hash
    transformed_fees = line_item_fees_orig.transform_keys { |k| underscore_safe_name(k) }
  
    # Build a new hash with keys in the defined order, pulling values from the transformed hash
    @fee_types.each_with_object({}) do |fee_type, ordered_fees|
      ordered_fees[fee_type] = transformed_fees.fetch(fee_type, nil)
    end
  end

end
