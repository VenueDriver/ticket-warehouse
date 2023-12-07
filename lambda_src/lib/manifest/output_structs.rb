module Manifest
  class TicketRows
    TopLevelStruct = Struct.new(:event_date, :venue, :event_title, 
    :total_sold, :total_face_value, :total_let, :ticket_rows, 
    :now_in_pacific_time,
    :event_id, :event_key, :label_as_final, :display_date, keyword_init: true) do
      def get_binding
        data = self
        binding
      end
    end

    Row = Struct.new(
      :venue, :event_id, :event, :event_date, 
      :ticket_name, :price, :surcharge, :per_ticket_let, 
      :quantity, :sum_subtotal, :sum_surcharge, 
      :sum_let_tax, :let_tax_rate_observed, keyword_init: true) do
        def total_face_value
          self.sum_subtotal
        end
        
        def total_let
          self.sum_let_tax
        end

        def total_bar_card
          "TOTAL_BAR_CARD_USED_HERE"
        end
      end
  end
end