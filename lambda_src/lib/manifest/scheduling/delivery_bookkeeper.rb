module Manifest
  class Scheduling
    class DeliveryBookkeeper
      attr_reader :dynamo_writer, :dynamo_reader
      def initialize( control_table_name )
        @dynamo_reader, @dynamo_writer = DynamoHelper.create_reader_and_writer(control_table_name)
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

      # Manifest::Scheduling::ReportPerformer::SendReportResults 
      def categorize_email_attempt_results(email_attempt_results)
        preliminary_results = email_attempt_results.prelim_results
        final_results = email_attempt_results.final_results

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
        event_ids_that_exist, event_ids_that_dont_exist = dynamo_reader.partition_event_by_exists_and_not_exists(event_id_list)
        event_ids_that_dont_exist
      end

      # EmailAttempt = Struct.new( ...
      # use #succeeded? and failed? to determine success or failure

      def partition_results_by_success(results)
        success_results, failure_results = results.partition { |_, result| result.succeeded? }
        [success_results.to_h, failure_results.to_h]
      end

    end
  end
end