require_relative 'report_variants.rb'
require_relative 'email_report.rb'

module Manifest
  class Main 
    class << self

      def perform_report(event_id, report_variant_in, ses_client)
        #placeholder

        # if report_variant_in == 'preliminary'
        #   Manifest::Main.preliminary_report(event_id,$ses_client)
        # elsif report_variant_in == 'final'
        #   Manifest::Main.final_report(event_id, $ses_client)
        # else
        #   raise "unknown report_variant: #{report_variant_in}"
        # end

        preliminary_report(event_id, ses_client)
      end

      def preliminary_report(event_id, ses_client)
        email_report = EmailReport.make_preliminary(event_id)
        
        email_report.send_ses_raw_email!(ses_client, to_addresses: EmailReport::MARTECH_TO)
      end

      def final_report(event_id, ses_client)
        final_report = EmailReport.make_final(event_id)
        accounting_report = EmailReport.make_accounting(event_id, to_addresses: EmailReport::MARTECH_TO)
          
        final_report.send_ses_raw_email!(ses_client)
        accounting_report.send_ses_raw_email!(ses_client, to_addresses: EmailReport::MARTECH_TO )
      end
    end
  end
end