require_relative 'report_variants.rb'
require_relative 'email_report.rb'

module Manifest
  class Main 
    class << self

      def preliminary_report(event_id)
        email_report = EmailReport.make_preliminary(event_id)
        #email_report.send_ses_raw_email!($ses_client,to_addresses:EmailReport::TO_ALL)
      end

      def final_report(event_id)
        final_report = EmailReport.make_final(event_id)
        accounting_report = EmailReport.make_accounting(event_id)
        
        
      end
    end
  end
end