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
      end

      def set_jan_02_marked_final
        event_id = '655293b9-089c-4451-8cf2-417f92144192'

        mark_report_final_sent(event_id)
      end

      def mark_report_final_sent(event_id)
        r1 = @delivery_bookkeeper.process_preliminary_succeeded([event_id])

        pp r1

        r2 = @delivery_bookkeeper.process_final_succeeded([event_id])

        pp r2

        r2
      end

      def set_jewel_jan_01_marked_final
        mark_report_final_sent(EVENT_IDS[:jewel_jan_01])

      end
    end

  end
end