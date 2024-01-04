require 'aws-sdk-ses'
require_relative 'report_selector.rb'
require_relative 'report_performer.rb'
require_relative 'delivery_bookkeeper.rb'
require_relative 'preview_schedule.rb'
require_relative 'email_destination_planner.rb'

require 'tzinfo'

module Manifest
  class Scheduling
    class Manager
      attr_reader :report_selector, :report_performer, :delivery_bookkeeper
      def initialize(env_in = ENV['ENV'], control_table_name)
        @report_selector = Manifest::Scheduling::ReportSelector.new(env_in)
        region = 'us-east-1'
        @ses_client = Aws::SES::Client.new(region:region)
        
        @destination_planner = AlwaysMartech.new

        @report_performer = Manifest::Scheduling::ReportPerformer.new(@ses_client, @destination_planner)
        @delivery_bookkeeper = Manifest::Scheduling::DeliveryBookkeeper.new(control_table_name)
      end

      def calculate_report_selection_using(reference_time = Manager.utc_datetime_now )
        reference_time = reference_time.to_datetime

        categories = @report_selector.select_events(reference_time)

        categories
      end

      def preview_next_1030PM_pacific_time
        next_1030_pm_timestamp = self.next_1030_pm_timestamp_pacific_time
        preview_schedule_for_pacific_time(next_1030_pm_timestamp)
      end

      def preview_schedule_for_now_in_pacific_time
        preview_schedule_for_pacific_time(self.now_in_pacific_time)
      end

      def preview_schedule_for_pacific_time(pacific_time_in)
        pacific_time_zone = TZInfo::Timezone.get('America/Los_Angeles')
        reference_time = pacific_time_zone.local_to_utc(pacific_time_in)

        calculate_schedule_preview_using(reference_time)
      end

      def calculate_schedule_preview_using(reference_time = Manager.utc_datetime_now )
        categorized_join_rows = self.calculate_report_selection_using(reference_time)

        preview = PreviewSchedule.new(categorized_join_rows)
        preview.summary_struct
      end

      def process_prelim_only_using(reference_time = Manager.utc_datetime_now )
        # calculate_report_selection_using returns a CategorizedJoinRows
        report_selection = self.calculate_report_selection_using(reference_time.to_datetime)
        prelim_only_selection = report_selection.clone_without_send_final
        prelim_only_selection.send_final = [] 
        report_selection = nil

        report_send_results = @report_performer.send_reports_for_categories(prelim_only_selection)
        #byebug

        bookkeeper_response = @delivery_bookkeeper.record_email_attempt_results(report_send_results)
        
        [prelim_only_selection, report_send_results, bookkeeper_response]
      end

      def process_prelim_only_from_pst(pst_timestamp)
        utc_timestamp = TZInfo::Timezone.get('America/Los_Angeles').local_to_utc(pst_timestamp)
        self.process_prelim_only_using(utc_timestamp)
      end

      def process_main_report_schedule_using(reference_time = Manager.utc_datetime_now )
        reference_time = reference_time.to_datetime

        report_selection = self.calculate_report_selection_using(reference_time)

        report_send_results = @report_performer.send_reports_for_categories(report_selection)
        #byebug

        bookkeeper_response = @delivery_bookkeeper.record_email_attempt_results(report_send_results)
        
        [report_selection, report_send_results, bookkeeper_response]
      end

      def self.utc_datetime_now
        DateTime.now.new_offset(0)
      end

      CurrentAndUpcoming = Struct.new(:current_state, :upcoming_schedule, keyword_init: true) do 
        def joined_hash
          {
            current_state: self.current_state.as_hash,
            upcoming_schedule: self.upcoming_schedule.as_hash
          }
        end
      end

      def create_current_and_upcoming_1030_pm_previews
        current_state = self.preview_schedule_for_now_in_pacific_time
        current_state.optional_description = "Current State"
        upcoming_schedule = self.preview_next_1030PM_pacific_time
        upcoming_schedule.optional_description = "Upcoming Schedule (10:30 PM)"

        CurrentAndUpcoming.new(current_state: current_state, upcoming_schedule: upcoming_schedule)
      end

      private 

      def next_1030_pm_timestamp_pacific_time
        now_in_pacific_time = self.now_in_pacific_time

        next_1030_pm_timestamp = DateTime.new(
          now_in_pacific_time.year, 
          now_in_pacific_time.month, 
          now_in_pacific_time.day, 22, 30, 0, 0, now_in_pacific_time.offset)
      end

      def now_in_pacific_time
        pacific_time_zone = TZInfo::Timezone.get('America/Los_Angeles')
        now_in_pacific_time = pacific_time_zone.utc_to_local(DateTime.now.new_offset(0))
      end
      #
    end
  end
end