with casted_data as (

select tw_events.event.location  as ev_location
, tw_events.event.id  as event_id
, tw_events.event.name  as event_name
, date( date_parse(tw_events.event.start, '%Y-%m-%d %H:%i:%s') ) as event_date
, tw_tickets.name as ticket_name
, tw_tickets.id as ticket_id
, coalesce( CAST( tw_tickets.price     as DECIMAL(10,2) ),  0.00 ) as price
, coalesce( CAST( tw_tickets.surcharge as DECIMAL(10,2) ),  0.00 ) as surcharge
, coalesce( CAST( tw_tickets.let_tax   as DECIMAL(10,2) ),  0.00 ) as let_tax
, coalesce( CAST( tw_tickets.sales_tax as DECIMAL(10,2) ),  0.00 ) as sales_tax
, coalesce( CAST( tw_tickets.venue_fee as DECIMAL(10,2) ),  0.00 ) as venue_fee

from ticket_warehouse_events tw_events
inner join ticket_warehouse_tickets tw_tickets 
on tw_tickets.event_id = tw_events.event.id
      
)

select ev_location as venue
, event_id
, event_name as event 
, event_date
, ticket_name
, CAST( price as  DECIMAL(10,2) ) as price
, CAST( surcharge as  DECIMAL(10,2) ) as surcharge
, CAST( let_tax as  DECIMAL(10,2) ) as per_ticket_let

, count( ticket_id ) as quantity
, CAST( sum( price ) as DECIMAL(10,2) ) as sum_subtotal
, CAST( sum( surcharge ) as DECIMAL(10,2) ) as sum_surcharge
, CAST( sum( let_tax ) as DECIMAL(10,2) ) as sum_let_tax
, CAST( (100 * sum( let_tax ) / sum(price)) as DECIMAL(10,2) ) as let_tax_rate_observed
, CAST( sum( sales_tax ) as DECIMAL(10,2) ) as sum_sales_tax
, CAST( sum( venue_fee ) as DECIMAL(10,2) ) as sum_venue_fee

from casted_data
where (((true and true and true)))
group by 
ev_location
, event_id
, event_name
, event_date
, ticket_name
, price
, surcharge
, let_tax
ORDER by ev_location, event_date, event_id , event_name, ticket_name