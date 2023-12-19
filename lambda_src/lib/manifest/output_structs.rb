module Manifest
  class TicketRows
    TopLevelStruct = Struct.new(:event_date, :venue, :event_title, 
    :total_sold, :total_face_value, :total_let, :ticket_rows, 
    :now_in_pacific_time, :total_bar_card,
    :total_sales_tax, :total_venue_fee, 
    :total_surcharge,
    :event_open_time,
    :filename_full, :email_subject_with_open_time,
    :event_id, :event_key, :label_as_final, :display_date, keyword_init: true) do
      def get_binding
        data = self
        binding
      end

      def filename_pdf
        "#{self.filename_full}.pdf"
      end

      def filename_csv
        "#{self.filename_full}.csv"
      end

      def dev_file_path
        # want to use venue, event_date, event_title
        event_date_part = self.event_date.gsub('-', '_')
        "#{event_date_part}_#{self.venue}_#{self.event_title}.html".gsub(' ', '_')
      end

      def dev_file_name_full
        base = File.expand_path("~/Desktop/manifest_demos")
        File.join(base, self.dev_file_path)
      end
    end

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