SELECT
  Event.organization_name AS venue_name,
  Event.name AS event_name,
  date_parse(Event.start, '%Y-%m-%d %H:%i:%s') AS event_date,
  "Order".id AS ticketsauce_order_id,
  "Order".first_name AS first_name,
  "Order".last_name AS last_name,
  "Order".email AS email,
  "Order".phone AS phone,
  "Order".opted_in AS opted_in,
  "Order".opted_in_sms AS opted_in_sms,
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
  date_parse(Event.start, '%Y-%m-%d %H:%i:%s'),
  "Order".id,
  "Order".first_name,
  "Order".last_name,
  "Order".email,
  "Order".phone,
  "Order".opted_in,
  "Order".opted_in_sms,
  ticket_data.ticket_type_name
ORDER BY 
  date_parse(Event.start, '%Y-%m-%d %H:%i:%s'),
  "Order".email