require 'aws-sdk-dynamodb'

module Manifest
  class Scheduling
    DEFAULT_DDB_TABLE_NAME = 'manifest_delivery_control-production'
  
    class DynamoHelperBase
      attr_reader :table_name
      def initialize(dynamodb ,table_name = DEFAULT_DDB_TABLE_NAME)
        @dynamodb = dynamodb
        @table_name = table_name
      end
    end
  
    CONTROL_INITIALIZED = 'initialized'
    PRELIM_SENT = 'prelim_sent'
    REPORT_CANCELED = 'report_canceled'
    FINAL_SENT = 'final_sent'
  
    VALID_REPORT_STATUSES = [CONTROL_INITIALIZED, PRELIM_SENT, REPORT_CANCELED, FINAL_SENT]
  
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
  
    class EventIdWrapper
      attr_reader :event_id, :table_name
      def initialize(event_id,table_name:)
        @event_id = event_id
        @table_name = table_name
      end
  
      def canceled_report_update_expression
        update_expression = 'SET report_status = :new_report_status'
        expression_attribute_values = { ':new_report_status' => REPORT_CANCELED }
      
        create_update_params(update_expression, expression_attribute_values)
      end
  
      def prelim_sent_update_expression( preliminary_sent_at: )
        update_expression = 'SET report_status = :new_report_status, preliminary_sent_at = :preliminary_sent_at'
        expression_attribute_values = { 
          ':new_report_status' => PRELIM_SENT,
          ':preliminary_sent_at' => preliminary_sent_at
        }
      
        create_update_params(update_expression, expression_attribute_values)
      end
  
      def final_sent_update_expression( final_sent_at: )
        update_expression = 'SET report_status = :new_report_status, final_sent_at = :final_sent_at'
        expression_attribute_values = { 
          ':new_report_status' => FINAL_SENT,
          ':final_sent_at' => final_sent_at
        }
      
        create_update_params(update_expression, expression_attribute_values)
      end
  
      private 
  
      def create_update_params( update_expression, expression_attribute_values, return_values: 'UPDATED_NEW')
        update_item_params = {
          table_name:self.table_name,
          key: {
            event_key: self.event_id
          },
          update_expression: update_expression,
          expression_attribute_values: expression_attribute_values,
          return_values: return_values # You can change this value based on your needs
        }
      end
    end
  
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
      def mark_preliminary_sent(event_id, preliminary_sent_at:)
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

    class ControlRow
      def initialize(raw_dynamo_result)
        @raw_dynamo_result = raw_dynamo_result
      end

      def event_id
        #stub
      end

      def report_status
        #stub
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


