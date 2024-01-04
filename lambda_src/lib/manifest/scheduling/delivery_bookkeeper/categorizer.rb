require_relative 'categorized_attempts.rb'

module Manifest
  class Scheduling
    class DeliveryBookkeeper

      class Categorizer
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

        def partition_results_by_success(results)
          success_results, failure_results = results.partition { |_, result| result.succeeded? }
          [success_results.to_h, failure_results.to_h]
        end

      end

    end
  end
end