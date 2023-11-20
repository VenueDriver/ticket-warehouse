require 'json'

require_relative 'ticket-warehouse'

def lambda_handler(event:, context:)
  puts "Received event: #{JSON.pretty_generate(event)}"

  StripeArchiver.new.archive_charges(time_range:time_range)

  warehouse = TicketWarehouse.new(
    client_id:     ENV['TICKETSAUCE_CLIENT_ID'],
    client_secret: ENV['TICKETSAUCE_CLIENT_SECRET']
  )
  warehouse.authenticate!
  warehouse.archive_events(time_range: event['time_range'])

  { statusCode: 200, body: JSON.generate('💪') }
end
