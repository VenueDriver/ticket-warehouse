SELECT
  Event.organization_name AS venue_name,
  Event.name AS event_name,
  MAX(date_parse(Event.start, '%Y-%m-%d %H:%i:%s')) AS event_date,
  "Order".id AS ticketsauce_order_id,
  MAX("Order".first_name) AS first_name,
  MAX("Order".last_name) AS last_name,
  "Order".email AS email,
  MAX("Order".phone) AS phone,
  MAX("Order".opted_in) AS opted_in,
  MAX("Order".opted_in_sms) AS opted_in_sms,
  ticket_data.ticket_type_name AS ticket_type_name
FROM 
  "ticket_warehouse-production".ticket_warehouse_events AS Event
INNER JOIN
  "ticket_warehouse-production".ticket_warehouse_orders AS "Order"
  ON Event.id = "Order".event_id
INNER JOIN 
  "ticket_warehouse-production".ticket_warehouse_tickets AS ticket_data 
  ON ticket_data.order_id = "Order".id
GROUP BY 
  Event.organization_name,
  Event.name,
  "Order".id,
  "Order".email,
  ticket_data.ticket_type_name
ORDER BY 
  MAX(date_parse(Event.start, '%Y-%m-%d %H:%i:%s')),
  "Order".email