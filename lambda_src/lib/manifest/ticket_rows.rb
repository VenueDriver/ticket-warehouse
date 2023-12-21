require_relative '../../athena-manager.rb'
require_relative 'dev_query.rb'
require 'tzinfo'

require_relative 'event_description.rb'
require_relative 'event_totals.rb'

require_relative 'now_in_pacific_time.rb'
require_relative 'ticket_rows/top_level.rb' 
require_relative 'ticket_rows/individual_row.rb'

require_relative 'with_calculated_fields.rb'


module Manifest
  class TicketRows
    include NowInPacificTime
    attr_reader  :ticket_rows_symbolized, :ticket_row_structs
    attr_reader :report_variant

    class NullInputData < StandardError
    end

    def initialize( ticket_rows_array, report_variant = 'preliminary' )
      @report_variant = report_variant

      if ticket_rows_array.nil?
        raise NullInputData.new("ticket_rows_array cannot be nil")
      end
      
      @ticket_rows_symbolized = ticket_rows_array.map do |data_hash|
        data_hash.transform_keys(&:to_sym)
      end

      @ticket_row_structs = @ticket_rows_symbolized.map do |row|
        Row.new(**row)
      end
      WithCalculatedFields.process!(@ticket_row_structs)

    end

    def output_struct
      json_hash = self.transformed_json_without_ticket_rows
      json_hash[:ticket_rows] = @ticket_row_structs

      TopLevelStruct.new(**json_hash)
    end
    
    # bar card pattern '%VIP%Bar%Card%'
    def transformed_json
      without_ticket_rows = self.transformed_json_without_ticket_rows

      h = without_ticket_rows.merge(ticket_rows: @ticket_rows_symbolized )
      
      #pp h 
      h
    end
    
    def transformed_json_without_ticket_rows
      ticket_row_structs = self.ticket_row_structs
      
      event_description = EventDescription.calculate(ticket_row_structs, report_variant_string:self.report_variant)
      totals = EventTotals.calculate(ticket_row_structs)
      
      h = {
        event_date: event_description.event_date,
        venue: event_description.venue,
        event_title: event_description.event_title,
        
        total_sold: totals.total_sold,
        total_face_value: totals.total_face_value,
        total_let: totals.total_let,
        total_bar_card: totals.total_bar_card,
        
        total_sales_tax: totals.total_sales_tax,
        total_venue_fee: totals.total_venue_fee,

        total_surcharge: totals.total_surcharge,
        
        event_id: event_description.event_id,
        
        now_in_pacific_time: now_in_pacific_time,
        
        label_as_final: false,
        
        display_date: event_description.display_date,
        
        filename_full: event_description.filename_full,
        email_subject_with_open_time: event_description.email_subject_with_open_time,
      }

      h
    end

  end
end