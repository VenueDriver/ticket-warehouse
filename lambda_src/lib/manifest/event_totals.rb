require_relative 'event_totals/totals_struct.rb'

module Manifest
  class EventTotals 
    def initialize(ticket_row_structs)
      @ticket_row_structs = ticket_row_structs
    end

    def calculate
      running_total = EventTotals::Totals.start_with_zeros
      converted_structs = EventTotals::Totals.with_converted_decimals(@ticket_row_structs)
      converted_structs.each do |row|
        running_total.total_sold += row.total_sold
        running_total.total_face_value += row.total_face_value
        running_total.total_let += row.total_let
        running_total.total_bar_card += row.total_bar_card
        running_total.total_sales_tax += row.total_sales_tax
        running_total.total_venue_fee += row.total_venue_fee
      end

      running_total.apply_formatting
    end

    def self.calculate(ticket_row_structs)
      self.new(ticket_row_structs).calculate
    end

  end
end