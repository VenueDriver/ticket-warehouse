require 'aws-sdk-ses'
require 'mail'
require_relative 'render_pdf.rb'
require_relative 'email_report.rb'
require_relative 'mail_format.rb'

module Manifest
  TEXT_CONTENT = "This is html_only"
  class SesTest

    def self.scratch
      region = 'us-east-1'
      $ses_client = Aws::SES::Client.new(region:region)

      aoki_id = '655293f5-1160-40da-8544-443b92144192'
      luxury_id = '655297f0-7e68-4e36-9911-515c92144192'

      email_report = EmailReport.new(aoki_id, 'preliminary')
    
      message = email_report.generate_message

      raw_mime_message = message.encoded

      $ses_client.send_raw_email({
        raw_message: { data: raw_mime_message}
      })
    end


  end
end