require 'aws-sdk-dynamodb'
require_relative 'dynamo_helper/constants.rb'
require_relative 'dynamo_helper/event_id_wrapper.rb'
require_relative 'dynamo_helper/base.rb'
require_relative 'dynamo_helper/initial_row.rb'
require_relative 'dynamo_helper/control_row.rb'
require 'byebug'

module Manifest
  class Scheduling
  
    class DynamoWriter < DynamoHelperBase      
      def initialize_control_rows(event_ids)
        results = []
        event_ids.each_slice(25) do |batch|
          results << self.initialize_control_rows_limit_25(batch)
        end
        results
      end

      def initialize_control_rows_limit_25(event_ids)
        request_items = self.create_batch_insert_request_items(event_ids)

        # Perform the BatchWriteItem operation
        dynamodb.batch_write_item(request_items: request_items)
      end

      def create_batch_insert_request_items(event_ids)
        InitialRow.batch_CONTROL_INITIALIZED(event_ids, table_name: self.table_name)
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

      # does not check for canceled reports or already sent reports
      # assumes you want to perform the update regardless of the current state
      def force_reset_to_preliminary_sent(event_id)
        update_using(event_id) do |event_id_wrapper|  
          event_id_wrapper.force_reset_to_preliminary_sent_expression
        end
      end

      # does not check for canceled reports or already sent reports
      # assumes you want to perform the update regardless of the current state
      def force_forward_to_final_sent(event_id, final_sent_at: DateTime.now)
        update_using(event_id) do |event_id_wrapper|
          event_id_wrapper.force_forward_to_final_sent_expression(final_sent_at: final_sent_at)
        end
      end

      REMOVE_CONTROL_ROW_RETURN_VALUES = 'ALL_OLD'

      # This is NOT for canceling reports, use cancel_report instead
      # We dont expect needing to use this under normal operations
      def delete_control_row(single_event_id)
        response = @dynamodb.delete_item({
          table_name: self.table_name,
          key: {
            event_key: single_event_id
          },
          return_values: REMOVE_CONTROL_ROW_RETURN_VALUES
        })
        # [NONE, ALL_OLD, UPDATED_OLD, ALL_NEW, UPDATED_NEW]
        puts "Delete successful. Deleted event_key #{single_event_id}, attributes: #{response.attributes}"
        response
      rescue Aws::DynamoDB::Errors::ServiceError => e
        puts "Error deleting item: #{e.message}"
      end
  
      private 
  
      def update_using(event_id,&block)
        #event_id_wrapper = EventIdWrapper.new(event_id, table_name: self.table_name)
        #not showm, it base construct sets up @event_id_factory = EventIdFactory.new(table_name)
        event_id_wrapper = @event_id_factory.make(event_id)

        update_params = block.call(event_id_wrapper) 
  
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
        results = []
        event_ids.each_slice(25) do |batch|
          results << self.fetch_control_rows_limit_25(batch)
        end
        results.flatten
      end

      def fetch_wrapped_control_rows(event_ids)
        raw_rows = fetch_control_rows(event_ids)

        ControlRow.map_to_list(raw_rows)
      end

      # BatchGetItem has a limit of 100 items
      # We are using 25 because  requesting too many at once 
      # increases the risk of unprocesssed keys because of the response time
      def fetch_control_rows_limit_25(event_ids)
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

      def find_rows_that_need_initialization(event_id_list)
        event_ids_that_exist, event_ids_that_dont_exist = self.partition_event_by_exists_and_not_exists(event_id_list)
        event_ids_that_dont_exist
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

    class DynamoHelper
      def self.create_reader_and_writer(table_name = Scheduling::DEFAULT_DDB_TABLE_NAME)
        dynamodb = Aws::DynamoDB::Client.new
        #byebug
        reader = DynamoReader.new(dynamodb, table_name)
        #byebug
        writer = DynamoWriter.new(dynamodb, table_name)
        [reader, writer]
      end
    end

  end
end


