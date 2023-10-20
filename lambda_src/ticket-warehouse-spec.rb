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

  it 'fetches events for a specific organization' do
    warehouse = TicketWarehouse.new(
      client_id:     ENV['TICKETSAUCE_CLIENT_ID'],
      client_secret: ENV['TICKETSAUCE_CLIENT_SECRET']
    )
    warehouse.authenticate!
    events = warehouse.fetch_events
    organization_id = events.first['Event']['organization_id']
    org_events = warehouse.fetch_events(organization_id: organization_id)
    expect(org_events).to be_a(Array)
    expect(org_events.first['Event']['organization_id']).to eq(organization_id)
  end

  it 'fetches events starting after a specified date' do
    warehouse = TicketWarehouse.new(
      client_id:     ENV['TICKETSAUCE_CLIENT_ID'],
      client_secret: ENV['TICKETSAUCE_CLIENT_SECRET']
    )
    warehouse.authenticate!
    start_after_date = '2023-01-01'
    events = warehouse.fetch_events(start_after: start_after_date)
    expect(events).to be_a(Array)
  end

  it 'fetches events starting before and after specified dates' do
    warehouse = TicketWarehouse.new(
      client_id:     ENV['TICKETSAUCE_CLIENT_ID'],
      client_secret: ENV['TICKETSAUCE_CLIENT_SECRET']
    )
    warehouse.authenticate!
    start_after_date = '2023-10-20'
    start_before_date = '2023-10-22'
    events = warehouse.fetch_events(
      start_before: start_before_date, 
      start_after: start_after_date)
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

  it 'fetches order details for a given order' do
    warehouse =  TicketWarehouse.new(
      client_id:     ENV['TICKETSAUCE_CLIENT_ID'],
      client_secret: ENV['TICKETSAUCE_CLIENT_SECRET'])
    warehouse.authenticate!
    events = warehouse.fetch_events
    event = events.first
    orders = warehouse.fetch_orders(event: event)
    order = orders.first
    order_details = warehouse.fetch_order_details(order: order)
    expect(order_details).to be_a(Hash)  # Assuming order details is a hash
  end

  it "fetches Stephane's test event" do
    warehouse =  TicketWarehouse.new(
      client_id:     ENV['TICKETSAUCE_CLIENT_ID'],
      client_secret: ENV['TICKETSAUCE_CLIENT_SECRET'])
    warehouse.authenticate!
    events = warehouse.fetch_events(organization_id:'651ed9a9-61e8-4262-a290-67620ad120f3')
    expect(events).to be_a(Array)
  end

  it 'fetches checkin IDs for a given event' do
    warehouse = TicketWarehouse.new(
      client_id:     ENV['TICKETSAUCE_CLIENT_ID'],
      client_secret: ENV['TICKETSAUCE_CLIENT_SECRET']
    )
    warehouse.authenticate!
    events = warehouse.fetch_events
    event = events.first
    checkin_ids = warehouse.fetch_checkin_ids(event: event)
    expect(checkin_ids).to be_a(Array)  # Assuming checkin_ids is an array
  end

  it 'archives events' do
    warehouse = TicketWarehouse.new(
      client_id:     ENV['TICKETSAUCE_CLIENT_ID'],
      client_secret: ENV['TICKETSAUCE_CLIENT_SECRET']
    )
    warehouse.authenticate!
    warehouse.archive_events(time_range:'current')
  end

  describe '#generate_file_path' do
    it 'generates a file path based on event data' do
      warehouse = TicketWarehouse.new(
        client_id:     ENV['TICKETSAUCE_CLIENT_ID'],
        client_secret: ENV['TICKETSAUCE_CLIENT_SECRET']
      )
      event = {
        'Event' => {
          'location_name' => 'Test Location',
          'name' => 'Test Event',
          'start' => '2023-10-15T20:00:00'
        }
      }
      expected_path = 'events/test-location/2023/October/15/test-event.json'
      expect(warehouse.generate_file_path(event:event, table_name:'events')).to eq(expected_path)
    end
  end
end
