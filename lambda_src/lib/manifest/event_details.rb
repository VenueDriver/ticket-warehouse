module Manifest
  class EventDetails
    Desciption = Struct.new(:venue, :event_title, :event_date, :display_date, :event_id, keyword_init: true)
    Totals = Struct.new(:total_sold, :total_face_value, :total_let, keyword_init: true)

    class << self

      def find_event_description(ticket_rows)
        first_row = ticket_rows.first
        event_date_string = first_row[:event_date]
        event_date_parsed = Date.parse(event_date_string, '%F')
        display_date = event_date_parsed.strftime('%m-%d-%Y')
        event_date_out = event_date_parsed.strftime('%F')
        venue = first_row[:venue]
        event_id = first_row[:event_id]
        event_title = first_row[:event]
        Desciption.new(venue: venue, event_title: event_title, event_id:event_id, event_date: event_date_out, display_date: display_date)
      end

      def find_totals(ticket_rows)
        totals = Totals.new(total_sold: 0, total_face_value: 0, total_let: 0)
        ticket_rows.each do |row|
          sum_subtotal_string = row[:sum_subtotal]
          face_value = BigDecimal(sum_subtotal_string)
  
          sum_let_tax_string = row[:sum_let_tax]
          let_tax = BigDecimal(sum_let_tax_string)
  
          qty = Integer(row[:quantity])
  
          totals.total_sold += qty
          totals.total_face_value += face_value
          totals.total_let += let_tax
        end
        totals
  
        totals_formatted = Totals.new(
          total_sold: totals.total_sold,
          total_face_value: "%.2f" % totals.total_face_value,
          total_let: "%.2f" % totals.total_let,
        )
      end

    end
  end
end
