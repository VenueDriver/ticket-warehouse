require_relative 'dynamo_helper.rb'
require_relative 'delivery_bookkeeper/categorized_attempts.rb'
require_relative 'delivery_bookkeeper/categorizer.rb'

module Manifest
  class Scheduling
    class DeliveryBookkeeper
      attr_reader :dynamo_writer, :dynamo_reader
      attr_reader :event_categorizer
      def initialize( control_table_name )
        @dynamo_reader, @dynamo_writer = DynamoHelper.create_reader_and_writer(control_table_name)
        @event_categorizer = Categorizer.new
      end
      
      def record_email_attempt_results(email_attempt_results)
        categorized_results = @event_categorizer.categorize_email_attempt_results(email_attempt_results)

        # process preim_succeeded
        # process final_succeeded
        # we dont currently have much meaningfiul to do with the failed results
        process_preliminary_succeeded(categorized_results.preliminary_succeeded)
        process_final_succeeded(categorized_results.final_succeeded)

        nil
      end

      def process_preliminary_succeeded(event_id_list)
        event_id_list = Array(event_id_list)
        event_ids_missing_from_dynamo = find_rows_that_need_initialization(event_id_list)
        
        #####
        self.dynamo_writer.initialize_control_rows(event_ids_missing_from_dynamo)

        event_id_list.each do |event_id|
          single_mark_preliminary_sent(event_id)
        end
      end

      def process_final_succeeded(event_id_list)
        event_id_list = Array(event_id_list)
        event_id_list.each do |event_id|
          single_mark_final_sent(event_id)
        end
      end

      def single_mark_preliminary_sent(event_id)
        self.dynamo_writer.mark_preliminary_sent(event_id)
      end

      def single_mark_final_sent(event_id)
        self.dynamo_writer.mark_final_sent(event_id)
      end

      def single_force_reset_to_preliminary_sent(event_id)
        self.dynamo_writer.force_reset_to_preliminary_sent(event_id)
      end

      def single_force_forward_to_final_sent(event_id, final_sent_at: DateTime.now)
        self.dynamo_writer.force_forward_to_final_sent(event_id, final_sent_at: final_sent_at)
      end

      def single_cancel_report(event_id)
        self.dynamo_writer.cancel_report(event_id)
      end
      
      private

      def find_rows_that_need_initialization(event_id_list)
        @dynamo_reader.find_rows_that_need_initialization(event_id_list)
      end

    end
  end
end