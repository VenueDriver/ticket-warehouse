require 'aws-sdk-ses'
require_relative 'report_selector.rb'
require_relative 'report_performer.rb'
require_relative 'delivery_bookkeeper.rb'
require_relative 'preview_schedule.rb'

require 'tzinfo'

module Manifest
  class Scheduling
    class Manager

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

      def preview_schedule_for_pacific_time(pacific_time_in)
        pacific_time_zone = TZInfo::Timezone.get('America/Los_Angeles')
        reference_time = pacific_time_zone.local_to_utc(pacific_time_in)

        calculate_schedule_preview_using(reference_time)
      end

      def calculate_schedule_preview_using(reference_time = DateTime.now )
        categorized_join_rows = self.calculate_report_selection_using(reference_time)

        preview = PreviewSchedule.new(categorized_join_rows)
        preview.summary_struct
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