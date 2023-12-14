module Manifest
  class EventDescription
    DescriptionStruct = Struct.new(:venue, :event_title, :event_date, :display_date, :event_id, keyword_init: true)
    attr_reader :ticket_row_structs

    def initialize(ticket_row_structs)
      @ticket_row_structs = ticket_row_structs
    end

    def calculate
      first_struct = @ticket_row_structs.first
      event_date_string = first_struct.event_date #first_row[:event_date]
      event_date_parsed = Date.parse(event_date_string, '%F')
      display_date = event_date_parsed.strftime('%m-%d-%Y')
      event_date_out = event_date_parsed.strftime('%F')
      venue = first_struct.venue #first_row[:venue]
      event_id = first_struct.event_id # first_row[:event_id]
      event_title = first_struct.event# first_row[:event]
      DescriptionStruct.new(venue: venue, event_title: event_title, event_id:event_id, event_date: event_date_out, display_date: display_date)
    end

    def self.calculate(ticket_row_structs)
      self.new(ticket_row_structs).calculate
    end
  end
end