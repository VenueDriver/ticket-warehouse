require 'aws-sdk-ses'
require 'mail'
require 'erb'

require_relative 'render_pdf.rb'
require_relative 'email_report.rb'
require_relative 'mail_format.rb'

module Manifest
  class SesTest

    class << self
      def test(to_addresses)
        region = 'us-east-1'
        $ses_client = Aws::SES::Client.new(region:region)
  
        aoki_id = '6552982d-5120-4e96-a0a4-4f7892144192'
        luxury_id = '655297f0-7e68-4e36-9911-515c92144192'
  
        #email_report = EmailReport.make_preliminary(aoki_id)
        email_report = EmailReport.make_accounting(aoki_id)
        
  
        email_report.send_ses_raw_email!($ses_client,to_addresses:to_addresses)     
      end

      def test_public
        test(EmailReport::TO_ALL)
      end

      def test_default_to
        test(EmailReport::DEFAULT_TO)
      end

    end
  end
end