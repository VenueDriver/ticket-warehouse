module Manifest
  class EventDetails
    Desciption = Struct.new(:venue, :event_title, :event_date, :display_date, :event_id, keyword_init: true)
    Totals = Struct.new(:total_sold, :total_face_value, :total_let, :total_bar_card, keyword_init: true)
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

      # row.sum_bar_card = rev_split.bar_card
      # row.subtotal_minus_bar_card = rev_split.subtotal_minus_bar_card
      def find_totals( ticket_row_structs )
        totals = Totals.new(total_sold: 0, total_face_value: 0, total_let: 0, total_bar_card: 0)
        ticket_row_structs.each do |row|
          #sum_subtotal_string = row.sum_subtotal #row[:sum_subtotal]
          face_value_string = row.subtotal_minus_bar_card
          face_value = BigDecimal(face_value_string)
  
          sum_let_tax_string = row.sum_let_tax
          let_tax = BigDecimal(sum_let_tax_string)
  
          qty = Integer(row.quantity)

          sum_bar_card_string = row.sum_bar_card
          bar_card = BigDecimal(sum_bar_card_string)
  
          totals.total_sold += qty
          totals.total_face_value += face_value
          totals.total_let += let_tax
          totals.total_bar_card += bar_card
        end
        totals
  
        totals_formatted = Totals.new(
          total_sold: totals.total_sold,
          total_face_value: "%.2f" % totals.total_face_value,
          total_let: "%.2f" % totals.total_let,
          total_bar_card: "%.2f" % totals.total_bar_card,
        )
      end

    end
  end
end
