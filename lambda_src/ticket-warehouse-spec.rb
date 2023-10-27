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
