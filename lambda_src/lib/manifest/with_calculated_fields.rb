module Manifest
  class WithCalculatedFields
    def initialize(ticket_rows)
      @ticket_rows = ticket_rows
    end

    def process!
      @ticket_rows.each do |row|
        rev_split = calculate_revenue_split(row)

        row.sum_bar_card = rev_split.bar_card
        row.subtotal_minus_bar_card = rev_split.subtotal_minus_bar_card
      end
      @ticket_rows
    end

    # bar card sql like pattern '%VIP%Bar%Card%'
    # ruby version is: /VIP.*Bar.*Card/
    RevenueSplit = Struct.new(:subtotal_minus_bar_card, :bar_card, keyword_init: true)
    def calculate_revenue_split(row)
      bar_card_pattern = /VIP.*Bar.*Card/

      is_not_bar_card = bar_card_pattern.match(row.ticket_name).nil?
      
      bar_card_amount_decimal_single = is_not_bar_card ? BigDecimal("0.00") : BigDecimal("100.00")
      bar_card_amount_decimal = bar_card_amount_decimal_single * Integer(row.quantity)

      subtotal_decimal = BigDecimal(row.sum_subtotal)
      
      subtotal_minus_bar_card_decimal = subtotal_decimal - bar_card_amount_decimal

      subtotal_minus_bar_card_string = "%.2f" % subtotal_minus_bar_card_decimal
      bar_card_amount_string = "%.2f" % bar_card_amount_decimal
      
      RevenueSplit.new(
        subtotal_minus_bar_card: subtotal_minus_bar_card_string,
        bar_card: bar_card_amount_string,
      )
    end

    def self.process!(ticket_rows)
      self.new(ticket_rows).process!
    end
  end
end