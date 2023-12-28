require_relative '../../../athena-manager.rb'
require_relative 'events_query.rb'
require_relative 'candidate_event_row.rb'

module Manifest
  class Scheduling 
    class CandidateEventReader 
      def initialize(env_in = ENV['ENV'])
        @athena_manager = AthenaManager.new(env_in)
      end

      def fetch_candidate_event_rows(event_start_date, event_end_date)
        raw = self.fetch_event_data(event_start_date, event_end_date)

        CandidateEventRow.transform_event_rows(raw) 
      end
  
      def fetch_event_data(event_start_date, event_end_date)
        query_string = EventsQuery.using_range(event_start_date, event_end_date)
  
        r = @athena_manager.start_query(query_string: query_string)
      end

      def self.test_me
        reader = self.new('production')
        date_start = Date.new(2024,1,1)
        date_end = Date.new(2024,1,3)

        r = reader.fetch_candidate_event_rows(date_start, date_end)
      end
    end
  end
end

