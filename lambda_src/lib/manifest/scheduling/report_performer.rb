require_relative 'email_attempt_struct.rb'

module Manifest
  class Scheduling
    class ReportPerformer
      def initialize(ses_client_instance)
        @ses_client = ses_client_instance
      end

      # Preconditions: Another class has already determined which reports to send.
      # This class is just performing a list of tasks
      def send_reports(final_report_event_ids:, preliminary_report_event_ids:)
        #email_attempt_results = {}
        prelim_results = {}
        final_results = {}     

        final_report_event_ids.each do |event_id|
          attempt_result = self.attempt_accounting_then_final(event_id)
          final_results[event_id] = attempt_result
        end

        preliminary_report_event_ids.each do |event_id|
          attempt_result = self.attempt_just_premliminary(event_id)
          prelim_results[event_id] = attempt_result
        end

        {
          prelim_results: prelim_results,
          final_results: final_results,
        }
      end

      #
      private

      def attempt_accounting_then_final(event_id)
        accounting_attempt_result = self.attempt_email do
          accounting_report = EmailReport.make_accounting(event_id )
          accounting_report.send_ses_raw_email!(@ses_client, to_addresses: EmailReport::MARTECH_TO )
        end

        if accounting_attempt_result.failed?
          return accounting_attempt_result
        end

        final_attempt_result = self.attempt_email do
          final_report = EmailReport.make_final(event_id)
          final_report.send_ses_raw_email!(@ses_client, to_addresses: EmailReport::MARTECH_TO )
        end
        final_attempt_result
      end

      def attempt_just_premliminary(event_id)
        attempt_result = self.attempt_email do 
          email_report = EmailReport.make_preliminary(event_id)
          email_report.send_ses_raw_email!(@ses_client, to_addresses: EmailReport::MARTECH_TO)
        end
        attempt_result
      end

      def attempt_email(&block)
        # Goal: use EmailAttempt to record success or failure
        # if theres an exception, EmailAttempt.failure(exception_object)
        raw_result = block.call
        EmailAttempt.success(raw_result)
      rescue => e
        EmailAttempt.failure(e)
      end
    end
  end
end