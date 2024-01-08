require 'csv'

module Manifest
  class FinalCsv < SurchargeCsv

    def header_row
      %w{
        venue
        event
        event_date

        ticket
        price
        per_ticket_let

        sold
        total_bar_card
        total_face_value
        total_let

        total_sales_tax
        total_service_charge
      }
    end

    def to_csv
        CSV.generate do |csv|
          csv << self.header_row
  
          ticket_row_structs.each do |row_struct|
            csv << self.convert_row_struct_to_csv_row(row_struct)
          end
        end
      end  

    def convert_row_struct_to_csv_row(row_struct)
      [
        row_struct.venue,
        row_struct.event,
        row_struct.event_date,

        row_struct.ticket_name,
        row_struct.price,
        row_struct.per_ticket_let,

        row_struct.quantity,
        row_struct.sum_bar_card,
        row_struct.subtotal_minus_bar_card,
        row_struct.sum_let_tax,

        row_struct.sum_sales_tax,
        row_struct.sum_venue_fee,
      ]
    end

  end
end