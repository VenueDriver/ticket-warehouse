module Manifest
  class EventDetails
    Desciption = Struct.new(:venue, :event_title, :event_date, :display_date, :event_id, keyword_init: true)
    Totals = Struct.new(:total_sold, :total_face_value, :total_let, :total_bar_card, 
      :total_sales_tax, :total_venue_fee, keyword_init: true) do
        def self.start_with_zeros
          self.new(
            total_sold: 0,
            total_face_value: BigDecimal("0.0"),
            total_let: BigDecimal("0.0"),
            total_bar_card: BigDecimal("0.0"),
            total_sales_tax: BigDecimal("0.0"),
            total_venue_fee: BigDecimal("0.0")
          )
        end
      end
    # bar card name pattern '%VIP%Bar%Card%'

    class << self

      def find_event_description(ticket_row_structs)
        first_struct = ticket_row_structs.first
        event_date_string = first_struct.event_date #first_row[:event_date]
        event_date_parsed = Date.parse(event_date_string, '%F')
        display_date = event_date_parsed.strftime('%m-%d-%Y')
        event_date_out = event_date_parsed.strftime('%F')
        venue = first_struct.venue #first_row[:venue]
        event_id = first_struct.event_id # first_row[:event_id]
        event_title = first_struct.event# first_row[:event]
        Desciption.new(venue: venue, event_title: event_title, event_id:event_id, event_date: event_date_out, display_date: display_date)
      end

      def find_totals(ticket_row_structs)
        totals = Totals.start_with_zeros
        ticket_row_structs.each do |row|
          qty = Integer(row.quantity)
          face_value = BigDecimal(row.subtotal_minus_bar_card)
          let_tax = BigDecimal(row.sum_let_tax)
          bar_card = BigDecimal(row.sum_bar_card)
          sales_tax = BigDecimal(row.sum_sales_tax)
          venue_fee = BigDecimal(row.sum_venue_fee)

          totals.total_sold += qty
          totals.total_face_value += face_value
          totals.total_let += let_tax
          totals.total_bar_card += bar_card
          totals.total_sales_tax += sales_tax
          totals.total_venue_fee += venue_fee
        end

        totals_formatted = Totals.new(
          total_sold: totals.total_sold,
          total_face_value: "%.2f" % totals.total_face_value,
          total_let: "%.2f" % totals.total_let,
          total_bar_card: "%.2f" % totals.total_bar_card,
          total_sales_tax: "%.2f" % totals.total_sales_tax,
          total_venue_fee: "%.2f" % totals.total_venue_fee
        )
      end

    end
  end
end
