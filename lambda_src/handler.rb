require 'json'

require_relative 'ticket-warehouse'

def lambda_handler(event:, context:)
  puts "Received event: #{JSON.pretty_generate(event)}"
  puts "Lambda context: #{JSON.pretty_generate(context)}"

  warehouse = TicketWarehouse.new(
    client_id:     ENV['TICKETSAUCE_CLIENT_ID'],
    client_secret: ENV['TICKETSAUCE_CLIENT_SECRET']
  )
  warehouse.authenticate!
  warehouse.archive_events(time_range: event['time_range'])

  { statusCode: 200, body: JSON.generate('💪') }
end
