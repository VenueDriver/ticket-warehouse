require 'aws-sdk-ses'
require 'aws-sdk-athena'
require 'json'
require_relative '../athena-manager'

module Report
  class Daily
    def initialize
      @ses_client = Aws::SES::Client.new(region:'us-east-1')
      @athena_client = Aws::Athena::Client.new(region: 'us-east-1')
      @athena_manager = AthenaManager.new()
    end

    def generate
      puts "Generating Daily Ticket Sales Report..."

      generate_party_pass_summary
      generate_regular_ticket_report
    end

    def generate_party_pass_summary

      query = <<-SQL
        SELECT
          DATE_FORMAT(DATE_TRUNC('week', CAST(event.start AS TIMESTAMP)), '%Y-%m-%d') AS week_start,
          ticket.ticket_type_name,
          element_at(ARRAY_AGG(CAST(ticket.price AS DECIMAL(10, 2))), 1) AS price,
          COUNT(*) AS tickets_sold,
          COUNT(IF(CAST(o."order".paid_date_utc AS TIMESTAMP) >= CURRENT_TIMESTAMP - INTERVAL '1' DAY, 1, NULL)) AS sales_last_24_hours
        FROM
          "ticket_warehouse-production".ticket_warehouse_tickets ticket
        JOIN
          "ticket_warehouse-production".ticket_warehouse_events event
          ON ticket.event_id = event.id
        JOIN
          "ticket_warehouse-production".ticket_warehouse_orders o
          ON ticket.order_id = o."order".id
        WHERE
          LOWER(ticket.ticket_type_name) LIKE '%party pass%'
          AND CAST(event.start AS TIMESTAMP) <= CURRENT_TIMESTAMP + INTERVAL '60' DAY
          AND event.organization_name IN
          ( 'Liquid Pool Lounge', 'OMNIA', 'LAVO Las Vegas', 'Wet Republic', 'Hakkasan Nightclub', 'JEWEL Nightclub', 'OMNIA San Diego', 'TAO Beach Dayclub', 'Marquee Nightclub', 'Marquee Dayclub', 'TAO Nightclub')
        GROUP BY
          DATE_FORMAT(DATE_TRUNC('week', CAST(event.start AS TIMESTAMP)), '%Y-%m-%d'),
          ticket.ticket_type_name
        ORDER BY
          week_start ASC
      SQL
    
      puts "Daily Ticket Sales Report"
      puts "Generated on #{Time.now.strftime('%Y-%m-%d %H:%M:%S')}"
    
      puts "\n"
      puts "Las Vegas Party Pass Summary by Week"
      puts "\n"

      query_results = @athena_manager.start_query(query_string:query)

      # Process the query results
      query_results.each do |row|
        puts row['ticket_type_name']
        puts "    Price:         #{row['price']}"
        puts "    Total Sales:   #{row['tickets_sold']}"
        puts "    Last 24 Hours: #{row['sales_last_24_hours']}"
        puts "\n"
      end

    end

    def generate_regular_ticket_report
      puts "\n"
      puts "Regular Ticket Sales Report"
      puts "\n"

      query = <<-SQL
        SELECT
          e."event".name AS event_name,
          e."event".organization_name AS venue_name,
          CAST(CAST(e."event".start AS TIMESTAMP) AS DATE) AS event_date,
          t.tickettype.name AS ticket_type_name,
          CAST(t.price AS DECIMAL(10, 2)) AS price,
          COUNT(*) AS quantity_sold,
          COUNT(IF(CAST(o."order".paid_date_utc AS TIMESTAMP) >= CURRENT_TIMESTAMP - INTERVAL '1' DAY, 1, NULL)) AS sales_last_24_hours
        FROM
          "ticket_warehouse-production".ticket_warehouse_events e
        JOIN
          "ticket_warehouse-production".ticket_warehouse_orders o
          ON e."event".id = o."order".event_id
        JOIN
          "ticket_warehouse-production".ticket_warehouse_tickets t
          ON o."order".id = t.order_id
        WHERE
          LOWER(t.tickettype.name) NOT LIKE '%party pass%'
          AND CAST(e."event".start AS TIMESTAMP) BETWEEN CURRENT_TIMESTAMP AND CURRENT_TIMESTAMP + INTERVAL '60' DAY
          AND event.organization_name IN
          ( 'Liquid Pool Lounge', 'OMNIA', 'LAVO Las Vegas', 'Wet Republic', 'Hakkasan Nightclub', 'JEWEL Nightclub', 'OMNIA San Diego', 'TAO Beach Dayclub', 'Marquee Nightclub', 'Marquee Dayclub', 'TAO Nightclub')
        GROUP BY
          e."event".name,
          e."event".organization_name,
          CAST(CAST(e."event".start AS TIMESTAMP) AS DATE),
          t.tickettype.name,
          CAST(t.price AS DECIMAL(10, 2))
        ORDER BY
          event_date ASC,
          event_name ASC,
          ticket_type_name ASC
      SQL
      
      query_results = @athena_manager.start_query(query_string:query)
      
      puts "Daily Ticket Sales Report"
      puts "Generated on #{Time.now.strftime('%Y-%m-%d %H:%M:%S')}"
      
      puts "\n"
      puts "Las Vegas Party Pass Summary by Week"
      puts "\n"
      
      # Process the query results
      
      # Step 1: Generate the list of weeks
      weeks = []
      start_date = Date.today
      end_date = start_date + 60
      while start_date <= end_date
        week_start = start_date - start_date.wday + 1
        week_end = week_start + 6
        weeks << "#{week_start} to #{week_end}"
        start_date += 7
      end

      # Step 2: Create the hash
      data = Hash.new { |hash, key| hash[key] = Hash.new { |hash, key| hash[key] = Hash.new { |hash, key| hash[key] = { "Event Date" => nil, "Tickets" => [] } } } }

      # Step 3: Iterate over the Athena results
      query_results.each do |row|
        event_date = Date.parse(row['event_date'])
        week_start = event_date - event_date.wday
        venue_name = row['venue_name']
        event_title = row['event_name']
        ticket_info = {
          "Ticket Type" => row['ticket_type_name'],
          "Price" => row['price'],
          "Total Sales" => row['quantity_sold'],
          "Last 24 Hours" => row['sales_last_24_hours']
        }

        # Add the event date and ticket info to the hash
        data[week_start][venue_name][event_title]["Event Date"] = event_date
        data[week_start][venue_name][event_title]["Tickets"] << ticket_info
      end

      # Step 5: Iterate over the hash to print the output
      data.each do |week_start, venues|
        puts "Week of #{week_start} through #{week_start + 6}"
        venues.each do |venue_name, events|
          puts "\n"
          puts "  Venue: #{venue_name}"
          events.each do |event_title, event_info|
            puts "\n"
            puts "    Event Title: #{event_title}"
            puts "    Event Date:  #{event_info["Event Date"]}"
            event_info["Tickets"].each do |ticket|
              puts "\n"
              puts "      Ticket Type:       #{ticket["Ticket Type"]}"
              puts "        Price:           #{ticket["Price"]}"
              puts "          Total Sales:   #{ticket["Total Sales"]}"
              puts "          Last 24 Hours: #{ticket["Last 24 Hours"]}"
            end
          end
        end
        puts "\n"
      end

    end

  end
end
