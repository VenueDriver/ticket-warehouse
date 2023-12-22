require_relative '../../athena-manager.rb'
require_relative 'dynamo_helper.rb'

module Manifest
  class Scheduling 
    def initialize(env_in = ENV['ENV'])
      @athena_manager = AthenaManager.new(env_in)
    end

    def self.scratch 
      obj = self.new('production')

      event_data_raw = obj.fetch_event_data('2024-01-01','2024-01-03')

      candidate_rows = obj.transform_event_rows(event_data_raw)

      filtered_rows = obj.filter_candidate_rows_less_than(candidate_rows, DateTime.new(2024,1,2,6))
      
      filtered_rows
    end

    #manifest is due when the start_utc is in the past
    # events that have already started
    def filter_candidate_rows_less_than(candidate_rows, utc_cutoff)
      candidate_rows.select do |row|
        row.event_start_utc_timestamp_parsed <= utc_cutoff
      end
    end

    def filter_candidate_rows_greater_than(candidate_rows, utc_cutoff)
      candidate_rows.select do |row|
        row.event_start_utc_timestamp_parsed >= utc_cutoff
      end
    end


    def fetch_event_data(event_start_date, event_end_date)
      query_string = select_events_query(event_start_date, event_end_date)

      r = @athena_manager.start_query(query_string: query_string)
    end

    class CandidateEventRow 
      def initialize(venue:,event_id:,event_date:,event_start_utc_timestamp:)
        @venue = venue
        @event_id = event_id
        @event_date = event_date
        @event_start_utc_timestamp = event_start_utc_timestamp
      end

      def event_date_parsed
        Date.parse(@event_date,'YYYY-MM-DD')
      end

      #example "2024-01-04 06:30:00.000"
      # correcsponds to format string: 'YYYY-MM-DD HH24:MI:SS.MS'
      def event_start_utc_timestamp_parsed
        DateTime.parse(@event_start_utc_timestamp, 'YYYY-MM-DD HH24:MI:SS.MS')
      end
    end

    def transform_event_rows(rows)
      rows.map do |row|
        venue = row['venue']
        event_id = row['event_id']
        event_date = row['event_date']
        event_start_utc_timestamp = row['event_start_utc_timestamp']
        CandidateEventRow.new(venue: venue, event_id: event_id, event_date: event_date, event_start_utc_timestamp: event_start_utc_timestamp)
      end
    end

    def select_events_query(event_start_date, event_end_date)
      ev_start_param = event_start_date.is_a?(String) ? event_start_date : event_start_date.strftime('%Y-%m-%d')
      ev_end_param = event_end_date.is_a?(String) ? event_end_date : event_end_date.strftime('%Y-%m-%d')

      <<~SQL
with casted_event_data as (
  select tw_events.event.location as venue
  , tw_events.event.id as event_id
  , CAST(CAST(tw_events.event.start AS TIMESTAMP) AS DATE) AS event_date
  , CAST(tw_events.event.start_utc AS TIMESTAMP) as event_start_utc_timestamp
  from ticket_warehouse_events tw_events
  where tw_events.event.location in 
  ( 'Liquid Pool Lounge', 'OMNIA', 'LAVO Las Vegas', 'Wet Republic', 'Hakkasan Nightclub', 'JEWEL Nightclub', 'OMNIA San Diego', 'TAO Beach Dayclub', 'Marquee Nightclub', 'Marquee Dayclub', 'TAO Nightclub')
)
select casted_event_data.venue
, casted_event_data.event_id
, casted_event_data.event_date
, casted_event_data.event_start_utc_timestamp
from casted_event_data
where casted_event_data.event_date >= DATE( '#{ev_start_param}' )
and casted_event_data.event_date <= DATE( '#{ev_end_param}' )
order by casted_event_data.event_date asc
      SQL
    end
  end
end