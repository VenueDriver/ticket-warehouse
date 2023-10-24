require 'aws-sdk-athena'

module Manager
  class Athena
      
    # Drop Athena tables.
    def self.drop_tables
      # puts "Dropping Athena tables..."

      # Initialize Athena client
      client = Aws::Athena::Client.new(
        region: 'us-east-1'
      )
      
      # Specify the Athena database and table prefix
      database = 'ticket_warehouse'
      prefix = 'ticket_warehouse_'
      
      # Drop tables with the specified prefix
      drop_tables_with_prefix(client, database, prefix)
    end

    private

    def self.drop_tables_with_prefix(client, database, prefix)
      # List all tables in the specified database
      table_names = list_tables(client, database)
      tables_to_drop = table_names.select { |table| table.start_with?(prefix) }
    
      # Drop each table with the specified prefix
      tables_to_drop.each do |table|
        puts "    Dropping table #{table}..."
        client.start_query_execution(
          query_string: "DROP TABLE #{database}.#{table}",
          query_execution_context: { database: database },
          work_group: 'TicketWarehouse'
        )
      end
    end

    def self.list_tables(client, database)
      # Execute a SHOW TABLES command to list all tables in the specified database
      result = client.start_query_execution(
        query_string: "SHOW TABLES IN #{database}",
        query_execution_context: { database: database },
        work_group: 'TicketWarehouse'
      )
    
      # Wait for the query to complete
      query_execution_id = result.query_execution_id
      status = nil
      until %w[SUCCEEDED FAILED CANCELLED].include?(status)
        sleep(1)
        status = client.get_query_execution(query_execution_id: query_execution_id).query_execution.status.state
      end
    
      # Fetch the results of the query
      results = client.get_query_results(query_execution_id: query_execution_id)
    
      # Extract the table names from the query results
      table_names = results.result_set.rows.map { |row| row.data.first.var_char_value }.compact
    
      table_names
    end
    

  end
end