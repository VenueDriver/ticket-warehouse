require 'json'
require 'aws-sdk-glue'

def lambda_handler(event:, context:)
  puts "Received event: #{JSON.pretty_generate(event)}"

  # Trigger the Glue crawlers to update the Athena tables.
  glue_client = Aws::Glue::Client.new(region: 'us-east-1')
  
  [
    'ticket-warehouse-events-crawler',
    'ticket-warehouse-orders-crawler',
    'ticket-warehouse-tickets-crawler',
    'ticket-warehouse-ticket-types-crawler',
    'ticket-warehouse-checkin-ids-crawler'
  ].each do |crawler_name|
    glue_client.start_crawler(name: crawler_name)
    puts "Started the Glue crawler: #{crawler_name}"
  end

  { statusCode: 200, body: JSON.generate('💪') }
end
