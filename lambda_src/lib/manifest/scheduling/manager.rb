require 'aws-sdk-ses'
require_relative 'report_selector.rb'
require_relative 'report_performer.rb'
require_relative 'delivery_bookkeeper.rb'
require_relative 'preview_schedule.rb'
require_relative 'email_destination_planner.rb'
require_relative 'demo_email_json_summary.rb'

require 'tzinfo'
require 'json'

module Manifest
  class Scheduling
    class Manager
      attr_reader :report_selector, :report_performer, :delivery_bookkeeper
      attr_reader :ses_client
      def initialize(env_in , control_table_name, ses_client_in:nil)
        @report_selector = Manifest::Scheduling::ReportSelector.new(env_in)
        
        @ses_client = ses_client_in || self.class.default_ses_client
        
        @destination_planner = self.class.set_destination_planner_from_global_settings
        #@destination_planner = AlwaysRich.new

        @report_performer = Manifest::Scheduling::ReportPerformer.new(@ses_client, @destination_planner)
        @delivery_bookkeeper = Manifest::Scheduling::DeliveryBookkeeper.new(control_table_name)
      end

      DEFAULT_SES_REGION = 'us-east-1'

      def self.create_from_lambda_input_event(event,env_in = ENV['ENV'], ses_client:)
        control_table_prefix = Scheduling::DEFAULT_DDB_PREFIX
        control_table_name = "#{control_table_prefix}-#{env_in}"
        self.new(env_in, control_table_name, ses_client_in:ses_client)
      end

      def self.set_destination_planner_from_global_settings
        use_distro = Scheduling.use_distribution_list
        if use_distro
          UsingDistributionList.new
        else 
          #AlwaysMartech.new

          # same as AlwaysMartech, it still sends to @to_addresses
          # but it will attempt to lookup and log
          # to console the live destination
          MartechLogDistroLookup.new 
        end
      end

      def self.create_run_options(event)
        RunOptions.new(event)
      end

      def self.default_ses_client(region = DEFAULT_SES_REGION)
        # not sure if we should use this much
        Aws::SES::Client.new(region:region)
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

      def process_reports_using_now
        now = Manager.utc_datetime_now
        process_main_report_schedule_using(now)
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

      def create_demo_email_summary_json_soft_launch
        demo = Manifest::Scheduling::DemoEmailJsonSummary.new(self)

        current_and_upcoming = demo.create_current_and_upcoming_1030_pm_previews

        data_hash = current_and_upcoming.joined_hash
      end

      def send_demo_email_summary_soft_launch
        demo = Manifest::Scheduling::DemoEmailJsonSummary.new(self)

        demo.demo_email_json_summary
      end

       

      def next_1030_pm_timestamp_pacific_time
        now_in_pacific_time = self.now_in_pacific_time

        next_1030_pm_timestamp = DateTime.new(
          now_in_pacific_time.year, 
          now_in_pacific_time.month, 
          now_in_pacific_time.day, 22, 31, 0, 0, now_in_pacific_time.offset)
      end

      def convert_to_pacific(utc_timestamp)
        tz = self.create_pacific_time_zone
        tz.utc_to_local(utc_timestamp)
      end

      def convert_to_utc(pacific_timestamp)
        tz = self.create_pacific_time_zone
        tz.local_to_utc(pacific_timestamp)
      end

      private

      def create_pacific_time_zone
        tz = TZInfo::Timezone.get('America/Los_Angeles')
      end

      def now_in_pacific_time
        pacific_time_zone = TZInfo::Timezone.get('America/Los_Angeles')
        now_in_pacific_time = pacific_time_zone.utc_to_local(DateTime.now.new_offset(0))
      end
      #
    end

    class RunOptions
      def initialize(raw_lambda_event)
        @raw_lambda_event = raw_lambda_event
      end

      def try_send_summary_email?
        @raw_lambda_event['try_send_summary_email'] == 'try_send_summary_email'
      end
    end
  end
end