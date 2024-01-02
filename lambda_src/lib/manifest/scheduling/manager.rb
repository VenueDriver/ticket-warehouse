require 'ses'

module Manifest
  class Scheduling
    class Manager
      require 'aws-sdk-ses'

      def initialize(env_in = ENV['ENV'], control_table_name)
        @report_selector = Manifest::Scheduling::ReportSelector.new(env_in)
        @ses_client = Aws::SES::Client.new(region: 'us-west-2') 
        @report_performer = Manifest::Scheduling::ReportPerformer.new(@ses_client)
        @delivery_bookkeeper = Manifest::Scheduling::DeliveryBookkeeper.new(control_table_name)
      end

      def calculate_report_selection_using(reference_time = DateTime.now)
        reference_time = reference_time.to_datetime

        categories = @report_selector.select_events(reference_time)

        categories
      end

      def process_main_report_schedule_using(reference_time = DateTime.now)
        reference_time = reference_time.to_datetime

        report_selection = self.calculate_report_selection_using(reference_time)

        report_send_results = @report_performer.send_reports_for_categories(report_selection)

        bookkeeper_response = @delivery_bookkeeper.record_email_attempt_results(report_send_results)
        
        [report_selection, report_send_results, bookkeeper_response]
      end

      #
    end
  end
end