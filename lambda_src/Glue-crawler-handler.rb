require 'json'
require 'aws-sdk-glue'

def lambda_handler(event:, context:)
  puts "Received event: #{JSON.pretty_generate(event)}"

  # Trigger the Glue crawlers to update the Athena tables.
  glue_client = Aws::Glue::Client.new(region: 'us_east_1')
  
  [
    'ticket_warehouse_events',
    'ticket_warehouse_orders',
    'ticket_warehouse_tickets',
    'ticket_warehouse_ticket_types',
    'ticket_warehouse_checkin_ids'
  ].each do |crawler_name|
    glue_client.start_crawler(name: crawler_name + '-' + ENV['ENV'])
    puts "Started the Glue crawler: #{crawler_name}"
  end

  { statusCode: 200, body: JSON.generate('💪') }
end
