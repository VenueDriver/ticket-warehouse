require 'aws-sdk-glue'

module Manager
  class Glue

    # Start Glue crawlers.
    def self.start_crawlers
      # puts "Starting Glue crawlers..."
      
      glue_client = Aws::Glue::Client.new(
        region: 'us-east-1',
      )
      
      [
        'ticket-warehouse-events-crawler',
        'ticket-warehouse-orders-crawler',
        'ticket-warehouse-tickets-crawler',
        'ticket-warehouse-checkin-ids-crawler'
      ].each do |crawler_name|
        start_crawler(glue_client, crawler_name)
      end
    end

    private

    def self.start_crawler(glue_client, crawler_name)
      begin
        glue_client.start_crawler(
          name: crawler_name
        )
        puts "    Crawler #{crawler_name} started successfully."
      rescue Aws::Glue::Errors::ServiceError => e
        puts "    Failed to start crawler: #{e.message}"
      end
    end

  end
end