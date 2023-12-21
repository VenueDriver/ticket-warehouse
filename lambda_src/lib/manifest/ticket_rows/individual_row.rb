module Manifest
  class TicketRows

    Row = Struct.new(
      :venue, :event_id, :event, :event_date, 
      :ticket_name, :price, :surcharge, :per_ticket_let, 
      :quantity, :sum_subtotal, :sum_surcharge, 
      :sum_let_tax, :let_tax_rate_observed, 
      :sum_sales_tax , :sum_venue_fee,
      :event_open_time,
      # calculated fields
      :sum_bar_card, :subtotal_minus_bar_card,

      keyword_init: true) do
        

      end
  end
end