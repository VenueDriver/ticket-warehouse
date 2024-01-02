require_relative 'constants.rb'

module Manifest
  class Scheduling
    class InitialRow
  
      class << self
        def batch_CONTROL_INITIALIZED(event_ids, table_name:)
          put_requests = event_ids.map do |event_id|
            create_put_request(event_id)
          end
  
          request_items = {
            table_name => put_requests
          } 
        end

        def create_put_request(event_id)
          item_data = {
            event_key: event_id,
            report_status: CONTROL_INITIALIZED
          }
          
          {
            put_request: { item:item_data}   
          }  
        end
  
      end
    end
  end
end