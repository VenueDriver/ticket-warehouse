require_relative 'report_variants.rb'
require_relative 'email_report.rb'

module Manifest
  class Main 
    class << self

      def perform_report(event_id, report_variant_in, ses_client)
        case report_variant_in
        when 'preliminary'
          email_report = EmailReport.make_preliminary(event_id)
        when 'final'
          email_report = EmailReport.make_final(event_id)
        when 'accounting'
          email_report = EmailReport.make_accounting(event_id)
        else
          raise "Invalid report variant: #{report_variant_in}"
        end
      
        email_report.send_ses_raw_email!(ses_client,
          to_addresses: ['Stephane.Tousignant@taogroup.com'],
          cc_addresses: ['marketing.technology.developers@taogroup.com'])
      end

      def preliminary_report(event_id, ses_client)
        email_report = EmailReport.make_preliminary(event_id)
        
        email_report.send_ses_raw_email!(ses_client,
          to_addresses: ['Stephane.Tousignant@taogroup.com'],
          cc_addresses: ['marketing.technology.developers@taogroup.com'])
      end

      def final_report(event_id, ses_client)
        final_report = EmailReport.make_final(event_id)
        accounting_report = EmailReport.make_accounting(event_id,
          to_addresses: ['Stephane.Tousignant@taogroup.com'],
          cc_addresses: ['marketing.technology.developers@taogroup.com'])
          
        final_report.send_ses_raw_email!(ses_client)
        accounting_report.send_ses_raw_email!(ses_client,
          to_addresses: ['Stephane.Tousignant@taogroup.com'],
          cc_addresses: ['marketing.technology.developers@taogroup.com'])
      end
    end
  end
end