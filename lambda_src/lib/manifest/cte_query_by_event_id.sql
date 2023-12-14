with casted_data as (

select tw_events.event.location  as ev_location
, tw_events.event.id  as event_id
, tw_events.event.name  as event_name
, date( date_parse(tw_events.event.start, '%Y-%m-%d %H:%i:%s') ) as event_date
, date_parse(tw_events.event.start, '%Y-%m-%d %H:%i:%s')  as event_open_time
, tw_tickets.name as ticket_name
, tw_tickets.id as ticket_id
, coalesce( CAST( tw_tickets.price     as DECIMAL(10,2) ), decimal '0.00' ) as price
, coalesce( CAST( tw_tickets.surcharge as DECIMAL(10,2) ), decimal '0.00' ) as surcharge
, coalesce( CAST( tw_tickets.let_tax   as DECIMAL(10,2) ),  decimal '0.00' ) as let_tax
, coalesce( CAST( tw_tickets.sales_tax as DECIMAL(10,2) ),  decimal '0.00' ) as sales_tax
, coalesce( CAST( tw_tickets.venue_fee as DECIMAL(10,2) ),  decimal '0.00' ) as venue_fee

from ticket_warehouse_events tw_events
inner join ticket_warehouse_tickets tw_tickets 
on tw_tickets.event_id = tw_events.event.id
      
)

select ev_location as venue
, event_id
, event_name as event 
, event_date
, event_open_time
, ticket_name
, price as price
, surcharge as surcharge
, let_tax as per_ticket_let

, count( ticket_id ) as quantity
, sum( price )  as sum_subtotal
, sum( surcharge ) as sum_surcharge
, sum( let_tax ) as sum_let_tax
, (100 * sum( let_tax ) / sum(price)) as let_tax_rate_observed
, sum( sales_tax ) as sum_sales_tax
, sum( venue_fee )  as sum_venue_fee

from casted_data
where (((true and true and true)))
group by 
ev_location
, event_id
, event_name
, event_date
, event_open_time
, ticket_name
, price
, surcharge
, let_tax
ORDER by ev_location, event_date, event_id , event_name, ticket_name