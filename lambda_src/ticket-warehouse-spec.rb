require_relative 'ticket-warehouse'

describe TicketWarehouse do
  it 'archives events' do
    warehouse = TicketWarehouse.new(
      client_id:     ENV['TICKETSAUCE_CLIENT_ID'],
      client_secret: ENV['TICKETSAUCE_CLIENT_SECRET']
    )
    warehouse.authenticate!
    warehouse.archive_events(time_range:'current')
  end

  it 'can download events locally' do
    warehouse = TicketWarehouse.init_default(localize:true,skip_athena_partitioning:true)

    expect{
      warehouse.archive_events(time_range:'current')
    }.not_to raise_error
  end

  it 'can download events locally with threading' do
    warehouse = TicketWarehouse.init_default(localize:true,skip_athena_partitioning:true)

    expect{
      warehouse.archive_events(time_range:'current', enable_threading:true)
    }.not_to raise_error
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
          'start' => '2023-10-15T20:00:00',
          'organization_name' => 'Test Location'
        }
      }
      expected_path = 'events/venue=test-location/year=2023/month=October/day=15/'
      expect(warehouse.generate_file_path(event:event, table_name:'events')).to eq(expected_path)
    end
  end
end
