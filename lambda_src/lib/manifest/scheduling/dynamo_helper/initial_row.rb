require_relative 'constants.rb'

module Manifest
  class Scheduling
  
    class InitialRow
  
      class << self
        def batch_CONTROL_INITIALIZED(event_ids, table_name:)
          item_data = event_ids.map do |event_id|
            {
              event_key: event_id,
              report_status: CONTROL_INITIALIZED
            }
          end
  
          put_requests = item_data.map do |single_item_data|
            {put_request: { item:single_item_data}   }  
          end
  
          request_items = {
            table_name => put_requests
          }
        end
  
      end
    end
  end
end