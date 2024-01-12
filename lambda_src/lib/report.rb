require 'aws-sdk-ses'
require 'aws-sdk-athena'
require 'json'
require_relative '../athena-manager'
require_relative '../venues'

module Report

  class Daily
    SENDER =    'Ticket Driver <reports@ticketdriver.com>'
    RECIPIENT = 'LVTickets@taogroup.com'

    def initialize
      @ses_client = Aws::SES::Client.new(region:'us-east-1')
      @athena_client = Aws::Athena::Client.new(region: 'us-east-1')
      @athena_manager = AthenaManager.new()
    end

    def generate
      puts "Generating Daily Ticket Sales Report..."

      report =
        generate_party_pass_summary +
        generate_regular_ticket_report
    end

    def send_email(report)
      begin
        @ses_client.send_email({
          destination: {
            to_addresses: ['Stephane.Tousignant@taogroup.com'],
            cc_addresses: ['marketing.technology.developers@taogroup.com'],
          },
          message: {
            body: {
              text: {
                charset: 'UTF-8',
                data: report,
              },
            },
            subject: {
              charset: 'UTF-8',
              data: 'Daily Ticket Sales Report',
            },
          },
          source: SENDER
        })
        puts 'Email sent successfully'
      rescue Aws::SES::Errors::ServiceError => error
        puts "Email not sent. Error message: #{error}"
      end
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
          AND CAST(event.start AS TIMESTAMP) > CURRENT_TIMESTAMP
          AND CAST(event.start AS TIMESTAMP) <= CURRENT_TIMESTAMP + INTERVAL '60' DAY
          AND event.organization_id IN ('#{Venues::IDLIST.join("', '")}')
        GROUP BY
          DATE_FORMAT(DATE_TRUNC('week', CAST(event.start AS TIMESTAMP)), '%Y-%m-%d'),
          ticket.ticket_type_name
        ORDER BY
          week_start ASC
      SQL
    
      report = ''

      report << "Daily Ticket Sales Report\n"
      report << "Generated on #{Time.now.getlocal('-08:00').strftime('%Y-%m-%d %H:%M:%S')} PT\n"
    
      report <<  "\n"
      report <<  "Las Vegas Party Pass Summary by Week\n"
      report <<  "\n"

      query_results = @athena_manager.start_query(query_string:query)

      # Process the query results
      query_results.each do |row|
        report <<  row['ticket_type_name'] + "\n"
        report <<  "    Price:         #{row['price']}\n"
        report <<  "    Total Sales:   #{row['tickets_sold']}\n"
        report <<  "    Last 24 Hours: #{row['sales_last_24_hours']}\n"
        report <<  "\n"
      end

      report
    end

    def generate_regular_ticket_report
      report = ''
      report <<  "\n"
      report <<  "Regular Ticket Sales Report\n"
      report <<  "\n"

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
          CAST(e."event".start AS TIMESTAMP) BETWEEN CURRENT_TIMESTAMP AND CURRENT_TIMESTAMP + INTERVAL '60' DAY
          AND event.organization_id IN ('#{Venues::IDLIST.join("', '")}')
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
        report <<  "Week of #{week_start} through #{week_start + 6}"
        venues.each do |venue_name, events|
          report <<  "\n"
          report <<  "  Venue: #{venue_name}\n"
          events.each do |event_title, event_info|
            report <<  "\n"
            report <<  "    Event Date:  #{event_info["Event Date"]}\n"
            report <<  "    Event Title: #{event_title}\n"
            event_info["Tickets"].each do |ticket|
              report <<  "\n"
              report <<  "      Ticket Type:       #{ticket["Ticket Type"]}\n"
              report <<  "        Price:           #{ticket["Price"]}\n"
              report <<  "          Total Sales:   #{ticket["Total Sales"]}\n"
              report <<  "          Last 24 Hours: #{ticket["Last 24 Hours"]}\n"
            end
          end
        end
        report <<  "\n"
      end

      report
    end

  end
end
