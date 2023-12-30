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

  end
end
