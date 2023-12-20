SELECT
    date_format(CAST(Event.start AS TIMESTAMP), '%y/%m/%d') || ' ' || Event.name AS event_details,
    CAST(CAST(Event.start AS TIMESTAMP) AS DATE) AS event_date,
    Event.organization_name AS venue,
    Event.name AS event,
    ticket_data.ticket_type_id,
    ticket_data.ticket_type_name,
    CAST(COALESCE(ticket_data.price, '0.00') AS DECIMAL(10, 2)) AS price_per_ticket,
    CAST(COALESCE(ticket_data.surcharge, '0.00') AS DECIMAL(10, 2)) AS surcharge_per_ticket,
    CAST(COALESCE(ticket_data.let_tax, '0.00') AS DECIMAL(10, 2)) AS let_per_ticket,
    CAST(COALESCE(ticket_data.venue_fee, '0.00') AS DECIMAL(10, 2)) AS service_charge_per_ticket,
    CAST(COALESCE(ticket_data.sales_tax, '0.00') AS DECIMAL(10, 2)) AS sales_tax_per_ticket,
    COUNT(*) AS sold,
    SUM(CAST(COALESCE(ticket_data.price, '0.00') AS DECIMAL(10, 2))) AS face_value_admissions_total,
    SUM(CAST(COALESCE(ticket_data.let_tax, '0.00') AS DECIMAL(10, 2))) AS let_total,
    SUM(CAST(COALESCE(ticket_data.venue_fee, '0.00') AS DECIMAL(10, 2))) AS service_charge_total,
    SUM(CAST(COALESCE(ticket_data.surcharge, '0.00') AS DECIMAL(10, 2))) AS surcharge_total,
    SUM(CAST(COALESCE(ticket_data.sales_tax, '0.00') AS DECIMAL(10, 2))) AS sales_tax_total
FROM
    "ticket_warehouse-production".ticket_warehouse_events AS Event
INNER JOIN
    "ticket_warehouse-production".ticket_warehouse_orders AS "Order" ON Event.id = "Order".event_id
INNER JOIN 
    "ticket_warehouse-production".ticket_warehouse_tickets ticket_data ON ticket_data.order_id = "Order"."order".id
LEFT OUTER JOIN 
    "ticket_warehouse-production".ticket_warehouse_stripe_charges as stripe_charges ON "Order".id = stripe_charges.ticketsauce_order_id
GROUP BY
    Event.start,
    Event.organization_name,
    Event.name,
    ticket_data.ticket_type_id,
    ticket_data.ticket_type_name,
    ticket_data.price,
    ticket_data.surcharge,
    ticket_data.let_tax,
    ticket_data.venue_fee,
    ticket_data.sales_tax
ORDER BY
    event_details