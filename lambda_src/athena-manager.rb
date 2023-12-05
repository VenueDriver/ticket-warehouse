require 'aws-sdk-athena'

class AthenaManager
  def initialize
    @client = Aws::Athena::Client.new(region: 'us-east-1')
    @workgroup = "TicketWarehouse-#{ENV['ENV']}"
    @database = "ticket_warehouse-#{ENV['ENV']}"
  end

  def repair_table(table_name)
    query_string = "MSCK REPAIR TABLE #{table_name}"
    start_query(query_string: query_string)
  end

  def start_query(query_string: nil, query_name: nil)
    if query_name
      named_query_id = get_named_query_id(query_name)

      unless named_query_id
        puts "Named query not found!"
        return
      end

      named_query_response = @client.get_named_query({
        named_query_id: named_query_id
      })
      query_string = named_query_response.named_query.query_string
    end

    unless query_string
      puts "No valid query string provided or found!"
      return
    end

    # puts "Running query: #{query_string}"

    params = {
      query_string: query_string,
      query_execution_context: {
        database: @database
      },
      work_group: @workgroup
    }

    response = @client.start_query_execution(params)
    wait_for_query_to_complete(response.query_execution_id)
  rescue Aws::Athena::Errors::InvalidRequestException => e
    puts "***************************"
    puts "*"
    puts "********* Invalid request: #{e.message}"
    puts "*"
    puts "* Query string: #{query_string}"
    puts "*"
    puts "***************************"
  end

  def get_named_query_id(query_name)
    response = @client.list_named_queries(work_group: @workgroup)

    response.named_query_ids.each do |query_id|
      query_details = @client.get_named_query({ named_query_id: query_id })
      return query_id if query_details.named_query.name == query_name
    end

    nil
  end

  def wait_for_query_to_complete(query_execution_id)
    loop do
      response = @client.get_query_execution({
        query_execution_id: query_execution_id
      })
      status = response.query_execution.status.state
      if %w[SUCCEEDED FAILED CANCELLED].include?(status)
        puts "Query #{query_execution_id} finished with status: #{status}"
        if status.eql?('FAILED')
          puts response.query_execution.status.state_change_reason
          puts response
          break
        else
          # When it succeeds we need to get the results.
          response = @client.get_query_results({
            query_execution_id: query_execution_id
          })
          
          # Initialize an empty array to hold the strings
          strings_list = []
          
          # Iterate through each row in the result set
          response.result_set.rows.each do |row|
            # Iterate through each data item in the row (though there appears to be only one data item per row in your example)
            row.data.each do |datum|
              # Extract the var_char_value from the datum and add it to the strings_list
              strings_list << datum.var_char_value
            end
          end
          
          # Return the list of strings
          return strings_list
        end
      end
      sleep(5)  # Wait for 5 seconds before polling again
    end
  end
end
