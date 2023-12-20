WITH OrderSubtotals AS (
  SELECT
    "Order".id AS order_id,
    CAST("Order".total_paid AS DECIMAL(10, 2)) - 
    (COALESCE(CAST("Order".lineitemfees.surcharge AS DECIMAL(10, 2)), DECIMAL '0.00' ) + 
     COALESCE(CAST("Order".lineitemfees.let_tax AS DECIMAL(10, 2)), DECIMAL '0.00') + 
     COALESCE(CAST("Order".lineitemfees.sales_tax AS DECIMAL(10, 2)), DECIMAL '0.00') + 
     COALESCE(CAST("Order".lineitemfees.venue_fee AS DECIMAL(10, 2)), DECIMAL '0.00')) AS subtotal
  FROM
    "ticket_warehouse-production".ticket_warehouse_orders AS "Order"
)
SELECT
  "Order".id AS ticketsauce_order_id,
  stripe_charges.payment_intent AS stripe_charge_payment_intent,
  Event.organization_name AS venue_title,
  Event.name AS event_title,
  lower(Event.name) as lowercase_event_title, 
  CAST(CAST(Event.start AS TIMESTAMP) AS DATE) AS event_date,
  SUM(JSON_ARRAY_LENGTH(CAST("Order".ticket AS JSON))) AS quantity,
  OS.subtotal AS subtotal,
  COALESCE("Order".lineitemfees.surcharge, '0.00') AS surcharge,
  COALESCE("Order".lineitemfees.let_tax, '0.00') AS LET,
  COALESCE("Order".lineitemfees.sales_tax, '0.00') AS sales_tax,
  COALESCE("Order".lineitemfees.venue_fee, '0.00') AS service_charge,
  0 AS donation_charity,
  "Order".total_paid AS total_paid,
  "Order".first_name AS order_first_name,
  "Order".last_name AS order_last_name,
  "Order".email AS order_email,
  "Order".opted_in AS opted_in,
  "Order".opted_in_sms AS opted_in_sms,
  CAST("Order".paid_date_utc AS TIMESTAMP) AS final_at_UTC,
  'false' AS void,
  'Stripe' AS payment_gateway,
  '' AS learned_from,
  CAST("Order".paid_date_utc AS TIMESTAMP) AS created_at_UTC,
  "Order".event_id AS event_id
FROM 
  "ticket_warehouse-production".ticket_warehouse_events AS Event
INNER JOIN
  "ticket_warehouse-production".ticket_warehouse_orders AS "Order"
  ON Event.id = "Order".event_id
LEFT OUTER JOIN 
  "ticket_warehouse-production".ticket_warehouse_stripe_charges as stripe_charges 
  ON "Order".id = stripe_charges.ticketsauce_order_id
LEFT JOIN
  OrderSubtotals AS OS
  ON "Order".id = OS.order_id
GROUP BY
  "Order".id,
  stripe_charges.payment_intent,
  Event.organization_name,
  Event.name,
  Event.start,
  "Order".lineitemfees.surcharge,
  "Order".lineitemfees.let_tax,
  "Order".lineitemfees.sales_tax,
  "Order".lineitemfees.venue_fee,
  "Order".total_paid,
  "Order".first_name,
  "Order".email,
  "Order".opted_in,
  "Order".opted_in_sms,
  "Order".last_name,
  "Order".paid_date_utc,
  "Order".event_id,
  OS.subtotal