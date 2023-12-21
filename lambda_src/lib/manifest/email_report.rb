require_relative 'event_data_fetcher.rb'
require_relative 'ticket_rows.rb'
require_relative 'erb_template.rb'
require_relative 'mail_format.rb'
require_relative 'report_variants.rb'

module Manifest
  class EmailReport
    DEFAULT_SENDER = "Ticketing<reports@ticketdriver.com>"
    DEFAULT_TO = ['richard.steinschneider@taogroup.com']
    TO_ALL = [
      'richard.steinschneider@taogroup.com',
      'stephane.tousignant@taogroup.com',
      'ryan.porter@taogroup.com',
    ]

    MARTECH_TO = [ 'marketing.technology.developers@taogroup.com']
    THIS_EMAIL_IS_HTML_ONLY = "This is html_only"

    class << self
      def make_preliminary(event_id)
        self.new(event_id, ReportVariants::Preliminary.new) 
      end

      def make_final(event_id)
        self.new(event_id, ReportVariants::Final.new)
      end

      def make_accounting(event_id)
        self.new(event_id, ReportVariants::Accounting.new)
      end
    end

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

    def send_ses_raw_email!(ses_client,**kw_args)
      message = generate_message(**kw_args)
      ses_client.send_raw_email({
        raw_message: { data: message.encoded }
      })
    end

    def generate_message(sender:DEFAULT_SENDER, to_addresses:DEFAULT_TO)
      process

      sender = Array(sender)

      output_structs = self.output_structs_step

      html_content = self.render_step
      email_subject = output_structs.email_subject_with_open_time
      

      message = MailFormat.generate_message(
        sender:sender,
        to_addresses:to_addresses, 
        email_subject:email_subject, 
        html_content: html_content,
        text_content: THIS_EMAIL_IS_HTML_ONLY
      )

      process_attachments(message, html_content:html_content, output_structs:output_structs)

      message
    end

    private

    def process_attachments(message, html_content:, output_structs:)
      pdf_filename, csv_filename = output_structs.filename_pdf, output_structs.filename_csv

      if @report_variant.has_pdf?
        #disabled
        #message.attachments[pdf_filename] = self.generate_pdf_content(html_content)
      end

      if @report_variant.has_surcharge_csv?
        message.attachments[csv_filename] = self.create_csv_string
      end

      message
    end

    def generate_pdf_content(html_content)
      ChromeHelper::RenderPdf.generate_pdf(html_content)
    end

    def create_csv_string
      surcharge_csv = SurchargeCsv.new(@output_structs_step)
      surcharge_csv.to_csv
    end

    def on_tap(str)
      file_name = @output_structs_step.dev_file_name_full
      File.write(file_name, str)
    end

  end
end