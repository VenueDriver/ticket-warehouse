require_relative '../../athena-manager.rb'
require_relative 'scheduling/dynamo_helper.rb'
require_relative 'scheduling/candidate_event_row.rb'
require_relative 'scheduling/events_query.rb'
require_relative 'scheduling/report_selector.rb'
require_relative 'scheduling/manager.rb'
require_relative 'scheduling/athena_dynamo_join.rb'
require_relative 'scheduling/candidate_event_reader.rb'
require_relative 'scheduling/report_performer.rb'
require_relative 'scheduling/delivery_bookkeeper.rb'
require_relative 'scheduling/simulator.rb'
require_relative 'scheduling/examples.rb'
require_relative 'scheduling/jan_2024_week_one.rb'
require_relative 'scheduling/preview_schedule.rb'
require_relative 'scheduling/email_destination_planner.rb'
require_relative 'scheduling/demo_email_json_summary.rb'

require 'tzinfo'

module Manifest
  class Scheduling 

    # def self.test_execute_current_prelim
    #   m = self.create_manager
    #   m.process_main_report_schedule_using
    # end
    class << self
      attr_accessor :use_distribution_list
    end
    self.use_distribution_list = false

    def self.create_manager
      env_in = 'production'
      control_table_name = 'manifest_delivery_control-production'
      ses_client = Scheduling::Manager.default_ses_client
      Scheduling::Manager.new(env_in, control_table_name, ses_client_in:ses_client)
    end

    def self.create_jan_2024
      
      j = Jan2024WeekOne.new
    end

    def self.test_preview_schedule(ref_time_in = DateTime.now)
      report_selector = ReportSelector.new('production')

      reference_time = ref_time_in

      categories_struct = report_selector.select_events(reference_time)

      preview_schedule = PreviewSchedule.new(categories_struct )

      preview_schedule.summary_struct
    end
  end
end
