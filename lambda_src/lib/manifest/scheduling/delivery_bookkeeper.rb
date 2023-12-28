module Manifest
  class Scheduling
    class DeliveryBookkeeper
      attr_reader :dynamo_writer, :dynamo_reader
      def initialize( control_table_name )
        dynamo_db_client = Aws::DynamoDB::Client.new
        @dynamo_writer = Manifest::DynamoWriter.new( dynamo_db_client, control_table_name)      
        @dyanmo_reader = Manifest::DynamoReader.new( dynamo_db_client, control_table_name)
      end

      CategorizedAttempts = Struct.new(
        :preliminary_succeeded ,
        :preliminary_failed ,
        :final_succeeded ,
        :final_failed,
        keyword_init: true
      ) 
      
      def record_email_attempt_results(email_attempt_results)
        categorized_results = categorize_email_attempt_results(email_attempt_results)

        # process preim_succeeded
        # process final_succeeded
        # we dont currently have much meaningfiul to do with the failed results
        process_preliminary_succeeded(categorized_results.preliminary_succeeded)
        process_final_succeeded(categorized_results.final_succeeded)

        nil
      end

      def process_preliminary_succeeded(event_id_list)
        event_ids_missing_from_dynamo = find_rows_that_need_initialization(event_id_list)
        self.dynamo_writer.initialize_control_rows(event_ids_missing_from_dynamo)

        event_id_list.each do |event_id|
          self.dynamo_writer.mark_preliminary_sent(event_id)
        end
      end

      def process_final_succeeded(event_id_list)
        event_id_list.each do |event_id|
          self.dynamo_writer.mark_final_sent(event_id)
        end
      end

      def categorize_email_attempt_results(email_attempt_results)
        preliminary_results = email_attempt_results[:preliminary]
        final_results = email_attempt_results[:final]

        prelim_succeeded, prelim_failed = partition_results_by_success(preliminary_results)
        final_succeeded, final_failed = partition_results_by_success(final_results)

        CategorizedAttempts.new(
          preliminary_succeeded: prelim_succeeded.keys,
          preliminary_failed: prelim_failed.keys,
          final_succeeded: final_succeeded.keys,
          final_failed: final_failed.keys
        )
      end
      
      private

      def find_rows_that_need_initialization(event_id_list)
        event_ids_that_exist, event_ids_that_dont_exist = dynamo_reader.partition_event_ids_by_existence(event_id_list)
        event_ids_that_dont_exist
      end

      def partition_results_by_success(results)
        success_results, failure_results = results.partition { |_, result| result.succeeded? }
        [success_results.to_h, failure_results.to_h]
      end

    end
  end
end