module Manifest
  class Scheduling 

    class CandidateEventRow 
      attr_reader :venue, :event_id, :event_title
      def initialize(venue:,event_id:,event_title:,event_date:,event_start_utc_timestamp:,local_event_start_timestamp:)
        @venue = venue
        @event_id = event_id
        @event_date = event_date
        @event_start_utc_timestamp = event_start_utc_timestamp
        @event_title = event_title
        @local_event_start_timestamp = local_event_start_timestamp
      end

      def event_date_parsed
        Date.parse(@event_date,'YYYY-MM-DD')
      end

      #example "2024-01-04 06:30:00.000"
      # correcsponds to format string: 'YYYY-MM-DD HH24:MI:SS.MS'
      def event_start_utc_timestamp_parsed
        DateTime.parse(@event_start_utc_timestamp, 'YYYY-MM-DD HH24:MI:SS.MS')
      end

      def self.from_athena_result(hash_from_athena)
        venue = hash_from_athena['venue']
        event_id = hash_from_athena['event_id']
        event_date = hash_from_athena['event_date']
        event_title = hash_from_athena['event_title']
        event_start_utc_timestamp = hash_from_athena['event_start_utc_timestamp']
        local_event_start_timestamp = hash_from_athena['local_event_start_timestamp']
        self.new(venue: venue, 
          event_id: event_id, 
          event_date: event_date, 
          event_title: event_title,
          event_start_utc_timestamp: event_start_utc_timestamp,
          local_event_start_timestamp: local_event_start_timestamp)
      end

      def self.transform_event_rows(rows)
        rows.map do |row|
          self.from_athena_result(row)
        end
      end
    end

  end
end

