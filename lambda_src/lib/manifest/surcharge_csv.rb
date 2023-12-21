require 'csv'

module Manifest
  class SurchargeCsv 
    KeyHeader = Struct.new(:header, :key ,:is_total)

    def initialize( top_level_struct)
      @top_level_struct = top_level_struct
    end

    def to_csv
      CSV.generate do |csv|
        csv << self.header_row

        ticket_row_structs.each do |row_struct|
          csv << self.convert_row_struct_to_csv_row(row_struct)
        end

        csv << self.totals_row
      end
    end

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

        total_surcharge
        total_sales_tax
        total_service_charge
      }
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

        row_struct.sum_surcharge,
        row_struct.sum_sales_tax,
        row_struct.sum_venue_fee,
      ]
    end

    def totals_row
      [
        '', #'venue',
        '', #'event',
        '', #'event_date',

        '', #'ticket',
        '', #'price',
        '', #'per_ticket_let',

        @top_level_struct.total_sold,
        @top_level_struct.total_bar_card,
        @top_level_struct.total_face_value,
        @top_level_struct.total_let,

        @top_level_struct.total_surcharge,
        @top_level_struct.total_sales_tax,
        @top_level_struct.total_venue_fee,
      ]
    end

    private

    def ticket_row_structs
      @top_level_struct.ticket_rows
    end
  end
end
