require_relative 'ticket-warehouse'

describe TicketWarehouse do
  it 'authenticates and sets the access token' do
    warehouse = TicketWarehouse.new(
      client_id:     ENV['TICKETSAUCE_CLIENT_ID'],
      client_secret: ENV['TICKETSAUCE_CLIENT_SECRET'])
    expect(warehouse.access_token).to be_nil
    warehouse.authenticate!
    expect(warehouse.access_token).not_to be_nil
  end

  it 'fetches events' do
    warehouse =  TicketWarehouse.new(
      client_id:     ENV['TICKETSAUCE_CLIENT_ID'],
      client_secret: ENV['TICKETSAUCE_CLIENT_SECRET'])
    warehouse.authenticate!
    events = warehouse.fetch_events
    expect(events).to be_a(Array)
  end

  it 'fetches orders for a given event' do
    warehouse =  TicketWarehouse.new(
      client_id:     ENV['TICKETSAUCE_CLIENT_ID'],
      client_secret: ENV['TICKETSAUCE_CLIENT_SECRET'])
    warehouse.authenticate!
    events = warehouse.fetch_events
    event = events.first
    orders = warehouse.fetch_orders(event: event)
    expect(orders).to be_a(Array)
  end
end
