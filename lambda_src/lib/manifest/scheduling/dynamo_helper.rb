require 'aws-sdk-dynamodb'
require_relative 'dynamo_helper/constants.rb'
require_relative 'dynamo_helper/event_id_wrapper.rb'
require_relative 'dynamo_helper/base.rb'
require_relative 'dynamo_helper/initial_row.rb'
require_relative 'dynamo_helper/control_row.rb'

module Manifest
  class Scheduling
  
    class DynamoWriter < DynamoHelperBase
  
      #uses BatchWriteItem
      def init_pending_reports(event_ids)
  
        request_items = InitialRow.batch_CONTROL_INITIALIZED(event_ids, table_name: self.table_name)
        
        # Perform the BatchWriteItem operation
        dynamodb.batch_write_item(request_items: request_items)
      end
  
      # Uses UpdateItem
      def cancel_report(event_id)
        update_using(event_id) do |event_id_wrapper|
          event_id_wrapper.canceled_report_update_expression
        end
      end
  
      # Uses UpdateItem
      def mark_preliminary_sent(event_id)
        update_using(event_id) do |event_id_wrapper|
          event_id_wrapper.prelim_sent_update_expression(preliminary_sent_at: DateTime.now)
        end
      end
  
      # Uses UpdateItem
      def mark_final_sent(event_id)
        update_using(event_id) do |event_id_wrapper|  
          event_id_wrapper.final_sent_update_expression(final_sent_at: DateTime.now)
        end
      end
  
      private 
  
      def update_using(event_id,&block)
        event_id_wrapper = EventIdWrapper.new(event_id, table_name: self.table_name)
  
        update_params = yield(event_id_wrapper)
  
        execute_update(update_params)
      end
  
      def execute_update(update_params)
        begin
          response = @dynamodb.update_item(update_params)
          puts "Update successful. Updated item: #{response.attributes}"
          response
        rescue Aws::DynamoDB::Errors::ServiceError => e
          puts "Error updating item: #{e.message}"
        end
      end
    end
  
    class DynamoReader < DynamoHelperBase
      def fetch_control_rows(event_ids)
        keys_to_get = event_ids.map { |event_id| { event_key: event_id } }
  
          # Create a BatchGetItem request
        request_items = create_request_items(event_ids)
  
        # Perform the BatchGetItem operation
        response = @dynamodb.batch_get_item(request_items: request_items)
        
              # Process the response and return the results
        if response.responses[table_name]
          return response.responses[table_name]
        else
          return []
        end
      end

      def partition_event_by_exists_and_not_exists(event_ids)
        control_rows = fetch_control_rows(event_ids)
        control_rows = control_rows.map { |raw_dynamo_result| ControlRow.new(raw_dynamo_result) }
      
        event_ids_that_exist = control_rows.map(&:event_id)
        event_ids_that_dont_exist = event_ids - event_ids_that_exist

        [event_ids_that_exist, event_ids_that_dont_exist]
      end
  
      private
  
      def create_request_items(event_ids)
        keys_to_get = event_ids.map { |event_id| { event_key: event_id } }
  
        # Create a BatchGetItem request
        request_items = {
          table_name => {
            keys: keys_to_get
          }
        }
      end
    end

  end
end


