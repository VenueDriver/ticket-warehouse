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

      
      #Users/richardsteinswiger/projects/ticket-warehouse/lambda_src/lib/manifest/scheduling/candidate_event_row.rb:26:in `summary_for_join_row_inspect': undefined method `event_start_utc_timestamp' for #<Manifest::Scheduling::CandidateEventRow:0x000000010e5dbfb

      def summary_for_join_row_inspect(verbose:true)
        event_date_str = self.event_date_parsed.strftime("%F")
        

        h = {
          event_title: self.event_title,
          event_date: event_date_str,
          event_id: self.event_id,
          event_start_utc_string: @event_start_utc_timestamp,
          local_event_start_string: @local_event_start_timestamp,
        #  event_start_utc: self.event_start_utc_timestamp_parsed,
        }

        # if !verbose
          
        # end
        h
      end

      #example "2024-01-04 06:30:00.000"
      # correcsponds to format string: 'YYYY-MM-DD HH24:MI:SS.MS'
      
      CANDIDATE_EVENT_ROW_FORMAT_STRING = 'YYYY-MM-DD HH24:MI:SS.MS'
      def event_start_utc_timestamp_parsed
        DateTime.parse(@event_start_utc_timestamp, CANDIDATE_EVENT_ROW_FORMAT_STRING )
      end

      def local_event_start_timestamp_parsed
        DateTime.parse(@local_event_start_timestamp, CANDIDATE_EVENT_ROW_FORMAT_STRING )
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

