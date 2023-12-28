module Manifest
  class Scheduling
    module EventsQuery 
      extend self

      def using_range(event_start_date, event_end_date)
        ev_start_param = event_start_date.is_a?(String) ? event_start_date : event_start_date.strftime('%Y-%m-%d')
        ev_end_param = event_end_date.is_a?(String) ? event_end_date : event_end_date.strftime('%Y-%m-%d')
  
        <<~SQL
  with casted_event_data as (
    select tw_events.event.location as venue
    , tw_events.event.name as event_title
    , tw_events.event.id as event_id
    , CAST(CAST(tw_events.event.start AS TIMESTAMP) AS DATE) AS event_date
    , CAST(tw_events.event.start_utc AS TIMESTAMP) as event_start_utc_timestamp
    from ticket_warehouse_events tw_events
    where tw_events.event.location in 
    ( 'Liquid Pool Lounge', 'OMNIA', 'LAVO Las Vegas', 'Wet Republic', 'Hakkasan Nightclub', 'JEWEL Nightclub', 'OMNIA San Diego', 'TAO Beach Dayclub', 'Marquee Nightclub', 'Marquee Dayclub', 'TAO Nightclub')
  )
  select casted_event_data.venue
  , casted_event_data.event_title
  , casted_event_data.event_date
  , casted_event_data.event_start_utc_timestamp
  , casted_event_data.event_id
  from casted_event_data
  where casted_event_data.event_date >= DATE( '#{ev_start_param}' )
  and casted_event_data.event_date <= DATE( '#{ev_end_param}' )
  order by casted_event_data.event_date asc
        SQL
      end
    end 
  end
end