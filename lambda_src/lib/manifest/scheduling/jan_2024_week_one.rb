require 'byebug'

module Manifest
  class Scheduling
    class Jan2024WeekOne
      EVENT_IDS = {
        jewel_jan_01: '654c5d04-b4c8-47f8-839d-573992144192'
      }

      def initialize(env_in = 'production')
        @candidate_event_reader = Manifest::Scheduling::CandidateEventReader.new(env_in)
        @delivery_bookkeeper = Manifest::Scheduling::DeliveryBookkeeper.new(DEFAULT_DDB_TABLE_NAME)
        @dynamo_reader = @delivery_bookkeeper.dynamo_reader
      end

      def set_jewel_jan_01_marked_final
        event_id = nil ; # pending

        event_id = EVENT_IDS[:jewel_jan_01]

        r1 = @delivery_bookkeeper.process_preliminary_succeeded([event_id])
        #byebug
        #r1 = @dynamo_reader.fetch_control_row(event_id)

        pp r1 

        #byebug
        r2 = @delivery_bookkeeper.process_final_succeeded([event_id])

        pp r2

      end
    end

  end
end