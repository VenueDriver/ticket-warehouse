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

require 'tzinfo'

module Manifest
  class Scheduling 

    def self.scratch 
      DeliveryBookkeeper.to_s
      ReportPerformer.to_s
      Manager.to_s

      Scheduling::CandidateEventReader.test_me
    end

    def self.simulate_1
      s = Examples.new

      s.scratch
    end

    def self.create_manager
      m = Manifest::Scheduling::Manager.new('production', DEFAULT_DDB_TABLE_NAME)
    end

    def self.create_jan_2024_week_one
      j = Manifest::Scheduling::Jan2024WeekOne.new('production')
    end

    class << self
      def simulate_report_select_10_pm
        self.simulate_report_selection_for_pacific_time(DateTime.new(2024,1,3,22))
      end

      def simulate_report_select_11_pm
        self.simulate_report_selection_for_pacific_time(DateTime.new(2024,1,3,23))
      end
    end

    def self.simulate_report_selection_for_pacific_time(pst_timestamp = DateTime.new(2024,1,3,21))
      tz = TZInfo::Timezone.get('America/Los_Angeles')
      utc_timestamp = tz.local_to_utc(pst_timestamp)
    
      utc_string = utc_timestamp.strftime("%F %T")
      pst_string = pst_timestamp.strftime("%F %T")

      puts "pacific_time#{pst_string},  utc_time#{utc_string}"
      puts "simulate_report_selection_for(#{pst_string})"

      test_preview_schedule(utc_timestamp)
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
