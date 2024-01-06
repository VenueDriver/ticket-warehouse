require_relative 'email_attempt_struct.rb'

module Manifest
  class Scheduling
    class ReportPerformer
      def initialize(ses_client_instance, destination_planner)
        @ses_client = ses_client_instance
        @email_destination_planner = destination_planner

        @final_report_limit_1 = false
      end

      def limit_final_reports_to_one_at_a_time!
        @final_report_limit_1 = true
      end

      def send_reports_for_categories(event_categories)
        as_only_ids = event_categories.convert_to_only_ids

        send_reports(final_report_event_ids: as_only_ids.send_final, preliminary_report_event_ids: as_only_ids.send_preliminary)
      end

      # Preconditions: Another class has already determined which reports to send.
      # This class is just performing a list of tasks
      SendReportResults = Struct.new(:prelim_results, :final_results, keyword_init: true)
      def send_reports(final_report_event_ids:, preliminary_report_event_ids:)
        #email_attempt_results = {}
        prelim_results = {}
        final_results = {}     

        # if @final_report_limit_1
        #   final_report_event_ids = Array(final_report_event_ids.first)
        # end

        final_report_event_ids.each do |event_id|
          attempt_result = self.attempt_accounting_then_final(event_id)
          final_results[event_id] = attempt_result
        end

        preliminary_report_event_ids.each do |event_id|
          attempt_result = self.attempt_just_premliminary(event_id)
          prelim_results[event_id] = attempt_result
        end

        SendReportResults.new(prelim_results: prelim_results, final_results: final_results)
      end

      #
      private

      def attempt_accounting_then_final(event_id)
        puts "Manifest::Scheduling::ReportPerformer#attempt_accounting_then_final(#{event_id})"
        #raise "not implemented yet"

        puts "  Sending accounting variant."

        accounting_attempt_result = self.attempt_email do
          accounting_report = EmailReport.make_accounting(event_id )
          accounting_report.send_ses_raw_email!(@ses_client, to_addresses: EmailReport::ACCOUNTING_PLUS_MARTECH )
        end

        if accounting_attempt_result.failed?
          return accounting_attempt_result
        end

        puts "  Sending final variant."

        final_attempt_result = self.attempt_email do
          final_report = EmailReport.make_final(event_id)
          sender_and_destination_struct = @email_destination_planner.final(final_report)
          to_addresses = sender_and_destination_struct.to_addresses
          to_addresses << EmailReport::MARTECH_PLUS_STEPHANE
          puts "To addresses: #{to_addresses}"
          final_report.send_ses_raw_email!(@ses_client, to_addresses: to_addresses )
        end
        final_attempt_result
      end

      def attempt_just_premliminary(event_id)
        attempt_result = self.attempt_email do 
          email_report = EmailReport.make_preliminary(event_id)
          sender_and_destination_struct = @email_destination_planner.preliminary(email_report)
          to_addresses = sender_and_destination_struct.to_addresses
          email_report.send_ses_raw_email!(@ses_client, to_addresses: to_addresses)
        end
        attempt_result
      end

      def attempt_email(&block)
        EmailAttempt.perform!(&block)
      end
    end
  end
end