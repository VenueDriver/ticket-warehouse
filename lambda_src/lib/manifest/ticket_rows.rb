require_relative '../../athena-manager.rb'
require_relative 'dev_query.rb'
require_relative 'omnia_data_rows_example.rb'
require 'tzinfo'

require_relative 'event_details.rb'
require_relative 'now_in_pacific_time.rb'
require_relative 'output_structs.rb'

module Manifest
  class TicketRows
    include NowInPacificTime
    attr_reader  :ticket_rows_symbolized

    def initialize( ticket_rows_array )
      @ticket_rows_symbolized = ticket_rows_array.map do |data_hash|
        data_hash.transform_keys(&:to_sym)
      end
    end

    def output_struct
      json_hash = transformed_json
      json_hash[:ticket_rows] = json_hash.delete(:ticket_rows).map do |row|
        Row.new(**row)
      end

      TopLevelStruct.new(**json_hash)
    end
    
    def transformed_json
      ticket_rows = self.ticket_rows_symbolized
      event_description = EventDetails.find_event_description(ticket_rows)
      totals = EventDetails.find_totals(ticket_rows)

      {
        event_date: event_description.event_date,
        venue: event_description.venue,
        event_title: event_description.event_title,

        total_sold: totals.total_sold,
        total_face_value: totals.total_face_value,
        total_let: totals.total_let,

        ticket_rows: ticket_rows,
        event_id: event_description.event_id,

        now_in_pacific_time: now_in_pacific_time,
        
        label_as_final: true,
        display_date: event_description.display_date,
      }
    end

  end
end