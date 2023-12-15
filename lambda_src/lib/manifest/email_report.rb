require_relative 'event_data_fetcher.rb'
require_relative 'ticket_rows.rb'
require_relative 'erb_template.rb'
require_relative 'mail_format.rb'

module Manifest
  class EmailReport
    DEFAULT_SENDER = "Ticketing<reports@ticketdriver.com>"
    DEFAULT_TO = ['richard.steinschneider@taogroup.com']
    TO_ALL = [
      'richard.steinschneider@taogroup.com',
      'stephane.tousignant@taogroup.com',
    'ryan.porter@taogroup.com',
    ]
    TEXT_CONTENT_3 = "This is html_only"

    def initialize(event_id, report_variant)
      @event_id = event_id
      @report_variant = report_variant
      @event_data_fetcher = EventDataFetcher.new('production')
      @report_processed_q = false
      @erb_render_template = ErbTemplate.new
    end

    attr_reader :from_athena_step, :ticket_rows_step
    attr_reader :render_step, :output_structs_step
    def process
      @from_athena_step = @event_data_fetcher.fetch_data_from_athena(@event_id)

      @ticket_rows_step = TicketRows.new(@from_athena_step, @report_variant)

      @output_structs_step = @ticket_rows_step.output_struct

      @render_step = @erb_render_template.render(@output_structs_step).tap do |str|
        on_tap( str )
      end
    end

    def generate_message(sender:DEFAULT_SENDER, to_addresses:TO_ALL)
      process

      sender = Array(sender)

      output_structs = self.output_structs_step

      html_content = self.render_step
      email_subject = output_structs.email_subject_with_open_time
      pdf_filename = "#{output_structs.filename_full}.pdf"

      message = MailFormat.generate_message(
        sender:sender,
        to_addresses:to_addresses, 
        email_subject:email_subject, 
        html_content: html_content,
        text_content: TEXT_CONTENT_3
      )

      message.attachments[pdf_filename] = ChromeHelper::RenderPdf.generate_pdf(html_content)

      message
    end

    private

    def on_tap(str)
      file_name = @output_structs_step.dev_file_name_full
      File.write(file_name, str)
    end

  end
end