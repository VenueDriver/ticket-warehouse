module Manifest
  class EventTotals 
    Totals = Struct.new(:total_sold, :total_face_value, :total_let, :total_bar_card, 
    :total_sales_tax, :total_venue_fee, keyword_init: true) do
      def self.start_with_zeros
        self.new(
          total_sold: 0,
          total_face_value: BigDecimal("0.00"),
          total_let: BigDecimal("0.00"),
          total_bar_card: BigDecimal("0.00"),
          total_sales_tax: BigDecimal("0.00"),
          total_venue_fee: BigDecimal("0.00")
        )
      end

      def self.from_ticket_row(row_struct)
        self.new(
            total_sold: row_struct.quantity,
            total_face_value: row_struct.subtotal_minus_bar_card,
            total_let: row_struct.sum_let_tax,
            total_bar_card: row_struct.sum_bar_card,
            total_sales_tax: row_struct.sum_sales_tax,
            total_venue_fee: row_struct.sum_venue_fee,
          )
      end

      def self.with_converted_decimals(ticket_row_structs)
        ticket_row_structs.map do |row|
          orig = self.from_ticket_row(row)
          orig.convert_to_decimals
        end
      end

      def convert_to_decimals
        self.class.new(
          total_sold: Integer(self.total_sold),
          total_face_value: BigDecimal(self.total_face_value),
          total_let: BigDecimal(self.total_let),
          total_bar_card: BigDecimal(self.total_bar_card),
          total_sales_tax: BigDecimal(self.total_sales_tax),
          total_venue_fee: BigDecimal(self.total_venue_fee)
        )
      end

      def apply_formatting
        # create copy of self with "%.2f" applie to everthing except total_sold
        self.class.new(
          total_sold: self.total_sold,
          total_face_value: "%.2f" % self.total_face_value,
          total_let: "%.2f" % self.total_let,
          total_bar_card: "%.2f" % self.total_bar_card,
          total_sales_tax: "%.2f" % self.total_sales_tax,
          total_venue_fee: "%.2f" % self.total_venue_fee
        )
      end
    end
  end
end