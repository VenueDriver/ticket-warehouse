SELECT
"Order".id AS ticketsauce_order_id,
stripe_charges.payment_intent as stripe_charge_payment_intent,
COALESCE(stripe_charges.payment_intent, "Order".id) AS order_id,
Event.organization_name AS venue_title,
Event.name AS event_title,
LOWER(Event.name) as lowercase_event_title, 
CAST(CAST(Event.start AS TIMESTAMP) AS DATE) AS event_date,
1 AS quantity,
COALESCE(CAST(ticket_data.price AS DECIMAL(10, 2)), DECIMAL '0.00') AS shared_price_per_ticket,
COALESCE(CAST(ticket_data.price AS DECIMAL(10, 2)), DECIMAL '0.00') AS face_value_subtotal,
COALESCE(CAST(ticket_data.surcharge AS DECIMAL(10, 2)), DECIMAL '0.00') AS shared_surcharge,
COALESCE(CAST(ticket_data.let_tax AS DECIMAL(10, 2)), DECIMAL '0.00') AS shared_let_tax_amount_currency,
COALESCE(CAST(ticket_data.sales_tax AS DECIMAL(10, 2)), DECIMAL '0.00') AS sales_tax_currency,
COALESCE(CAST(ticket_data.venue_fee AS DECIMAL(10, 2)), DECIMAL '0.00') AS service_charge_currency,
0 AS donation_charity,
(
  COALESCE(CAST(ticket_data.price AS DECIMAL(10, 2)), DECIMAL '0.00') + 
  COALESCE(CAST(ticket_data.surcharge AS DECIMAL(10, 2)), DECIMAL '0.00') + 
  COALESCE(CAST(ticket_data.let_tax AS DECIMAL(10, 2)), DECIMAL '0.00') + 
  COALESCE(CAST(ticket_data.sales_tax AS DECIMAL(10, 2)), DECIMAL '0.00') + 
  COALESCE(CAST(ticket_data.venue_fee AS DECIMAL(10, 2)), DECIMAL '0.00')
) AS total,
ticket_data.ticket_type_name AS ticket_type_name,
LOWER(ticket_data.ticket_type_name) as lowercase_ticket_type_name,
ticket_data.ticket_type_id AS ticket_type_id,
ticket_data.name AS ticket_holder_name,
"Order".first_name AS order_first_name,
"Order".last_name AS order_last_name,
CAST("Order".paid_date_utc AS TIMESTAMP) AS final_at_UTC,
'false' AS void,
'Stripe' AS payment_gateway,
'' AS learned_from,
ticket_data.id AS id,
CAST("Order".paid_date_utc AS TIMESTAMP) AS created_at_UTC,
"Order".event_id AS event_id,
ticket_data.redeemed AS ticket_redeemed,
ticket_data.promo_code AS ticket_promo_code
FROM 
"ticket_warehouse-production".ticket_warehouse_events AS Event
INNER JOIN
"ticket_warehouse-production".ticket_warehouse_orders AS "Order"
ON Event.id = "Order".event_id
INNER JOIN "ticket_warehouse-production".ticket_warehouse_tickets ticket_data on ticket_data.order_id = "Order"."order".id
LEFT OUTER JOIN 
"ticket_warehouse-production".ticket_warehouse_stripe_charges as stripe_charges 
on "Order".id = stripe_charges.ticketsauce_order_id