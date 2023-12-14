module Manifest
  class EventDescription
    DescriptionStruct = Struct.new(:venue, :event_title, 
      :event_date, :display_date, :event_id, 
      :filename_date_part, :filename_venue_part,  
      :subject_open_time_part, :subject_date_part,
      :variant_title,
      keyword_init: true) do
        def filename_without_variant
          "TICKET SALES MANIFEST_#{filename_date_part}_#{filename_venue_part}"
        end

        def filename_full
          "#{self.variant_title} #{filename_without_variant}"
        end

        def email_subject_with_open_time
          email_subject_base = "#{self.venue} #{self.subject_date_part} #{self.event_title} | #{self.variant_title} TICKET SALES MANIFEST"

          "#{email_subject_base} #{subject_open_time_part}"
        end

      end
    attr_reader :ticket_row_structs

    def initialize(ticket_row_structs,report_variant_string:'PRELIMINARY')
      @ticket_row_structs = ticket_row_structs
      @report_variant_string = report_variant_string
    end

    def calculate(variant_title_in = nil)
      first_struct = @ticket_row_structs.first
      event_date_string = first_struct.event_date #first_row[:event_date]
      event_date_parsed = Date.parse(event_date_string, '%F')
      display_date = event_date_parsed.strftime('%m-%d-%Y')
      event_date_out = event_date_parsed.strftime('%F')
      
      venue = first_struct.venue #first_row[:venue]
      event_id = first_struct.event_id # first_row[:event_id]
      event_title = first_struct.event# first_row[:event]
      
      filename_date_part = event_date_parsed.strftime('%m%d%Y')
      filename_venue_part = venue.gsub(' ','')

      subject_date_part = event_date_parsed.strftime("%a %d-%b").upcase
      #subject_open_time_part = first_struct.event_open_time.strftime("%I:%M%p")
      puts "EVENT OPEN TIME: #{first_struct.event_open_time}"
      
      # %H:%i:%s
      event_open_time_string = first_struct.event_open_time
      open_time_parsed = DateTime.parse(event_open_time_string, '%F %H:%i:%s')
      subject_open_time_part = open_time_parsed.strftime("%I:%M%p")
      variant_title = variant_title_in || @report_variant_string

      d = DescriptionStruct.new(venue: venue, 
        event_title: event_title, 
        event_id:event_id, 
        event_date: event_date_out, 
        display_date: display_date,
        filename_date_part: filename_date_part,
        filename_venue_part:filename_venue_part,
        subject_date_part:subject_date_part,
        subject_open_time_part:subject_open_time_part,
        variant_title:variant_title,
      )

      puts "D: #{d.email_subject_with_open_time}"
      puts "D: #{d.filename_without_variant}"
      d
    end

    def self.calculate(ticket_row_structs,report_variant_string:'PRELIMINARY')
      self.new(ticket_row_structs,
        report_variant_string:report_variant_string).calculate
    end
    
  end
end