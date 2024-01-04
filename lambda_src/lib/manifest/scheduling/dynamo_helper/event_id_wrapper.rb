require 'aws-sdk-dynamodb'
require_relative 'constants.rb'

module Manifest
  class Scheduling

    class EventIdFactory
      def initialize(table_name)
        @table_name = table_name
      end

      def make(event_id)
        EventIdWrapper.new(event_id, table_name: @table_name)
      end
    end
  
    class EventIdWrapper
      attr_reader :event_id, :table_name
      def initialize(event_id, table_name:)
        @event_id = event_id
        @table_name = table_name
      end
  
      def canceled_report_update_expression
        update_expression = 'SET report_status = :new_report_status'
        expression_attribute_values = { ':new_report_status' => REPORT_CANCELED }
      
        create_update_params(update_expression, expression_attribute_values)
      end
  
      def prelim_sent_update_expression( preliminary_sent_at: )
        converted_preliminary_sent_at = convert_timestamp_to_string_for_dynamodb(preliminary_sent_at)
        
        update_expression = 'SET report_status = :new_report_status, preliminary_sent_at = :preliminary_sent_at'
        expression_attribute_values = { 
          ':new_report_status' => PRELIM_SENT,
          ':preliminary_sent_at' => converted_preliminary_sent_at
        }
      
        create_update_params(update_expression, expression_attribute_values)
      end
  
      def final_sent_update_expression( final_sent_at: )
        converted_final_sent_at = convert_timestamp_to_string_for_dynamodb(final_sent_at)
        
        update_expression = 'SET report_status = :new_report_status, final_sent_at = :final_sent_at'
        expression_attribute_values = { 
          ':new_report_status' => FINAL_SENT,
          ':final_sent_at' => converted_final_sent_at
        }
      
        create_update_params(update_expression, expression_attribute_values)
      end

      # Does not check for canceled reports or already sent reports
      # Assumes caller has already checked for those conditions if required 
      def force_reset_to_preliminary_sent_expression
        update_expression = 'SET report_status = :new_report_status, final_sent_at = :final_sent_at'
        expression_attribute_values = { 
          ':new_report_status' => PRELIM_SENT,
          ':final_sent_at' => nil
        }
      
        create_update_params(update_expression, expression_attribute_values)
      end

      # Will not check for canceled reports or already sent reports
      # assumes want to perform update uncoditionally
      def force_forward_to_final_sent_expression(final_sent_at:)
        # Currently, this is identical to final_sent_update_expression
        # if this somehow needs to change separately, 
        # we modify this section 
        final_sent_update_expression(final_sent_at: final_sent_at)
      end
  
      DEFAULT_RETURN_VALUES = 'ALL_NEW'
      DDB_TIMESTAMP_FORMAT = '%Y-%m-%dT%H:%M:%S.%LZ'

      private 

      def convert_timestamp_to_string_for_dynamodb(timestamp)
        timestamp.strftime(DDB_TIMESTAMP_FORMAT)
      end
  
      def create_update_params( update_expression, expression_attribute_values, return_values: DEFAULT_RETURN_VALUES)
        update_item_params = {
          table_name:self.table_name,
          key: {
            event_key: self.event_id
          },
          update_expression: update_expression,
          expression_attribute_values: expression_attribute_values,
          # [NONE, ALL_OLD, UPDATED_OLD, ALL_NEW, UPDATED_NEW]
          return_values: return_values # 
        }
      end
    end

  end
end


