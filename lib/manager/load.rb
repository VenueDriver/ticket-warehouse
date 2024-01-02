require_relative '../../lambda_src/ticket-warehouse'

module Manager
  class Load
      
    # Run ETL for the given time period.
    def self.run(time_range:'all', threads:4)
      puts "Running ETL for #{time_range}..."

      unless ENV['TICKETSAUCE_CLIENT_ID'] && ENV['TICKETSAUCE_CLIENT_SECRET']
        raise "TICKETSAUCE_CLIENT_ID and TICKETSAUCE_CLIENT_SECRET must be set in the environment."
      end

      StripeArchiver.new.archive_charges(time_range:time_range)

      warehouse = TicketWarehouse.new(
        client_id:     ENV['TICKETSAUCE_CLIENT_ID'],
        client_secret: ENV['TICKETSAUCE_CLIENT_SECRET']
      )
      warehouse.authenticate!
      warehouse.archive_events(time_range:time_range, num_threads:threads)
      
    end

  end
end