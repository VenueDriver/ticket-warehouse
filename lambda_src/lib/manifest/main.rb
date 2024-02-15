require_relative 'report_variants.rb'
require_relative 'email_report.rb'
require 'aws-sdk-dynamodb'

module Manifest
  class Main 
    @dynamodb_client = Aws::DynamoDB::Client.new
    @table_name = Manifest::Scheduling::DEFAULT_DDB_TABLE_NAME
    @dynamo_writer = Manifest::Scheduling::DynamoWriter.new(@dynamodb_client, @table_name)

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
          to_addresses: ['Stephane.Tousignant@taogroup.com', 'marketing.technology.developers@taogroup.com'])
      end

      def mark_as_preliminary_sent(event_id)
        @dynamo_writer.mark_preliminary_sent(event_id)
      end

      def preliminary_report(event_id, ses_client)
        email_report = EmailReport.make_preliminary(event_id)
        
        email_report.send_ses_raw_email!(ses_client,
          to_addresses: ['Stephane.Tousignant@taogroup.com', 'marketing.technology.developers@taogroup.com'])
      end

      def final_report(event_id, ses_client)
        final_report = EmailReport.make_final(event_id)
        accounting_report = EmailReport.make_accounting(event_id,
          to_addresses: ['Stephane.Tousignant@taogroup.com', 'marketing.technology.developers@taogroup.com'])
          
        final_report.send_ses_raw_email!(ses_client)
        accounting_report.send_ses_raw_email!(ses_client,
          to_addresses: ['Stephane.Tousignant@taogroup.com', 'marketing.technology.developers@taogroup.com'])
      end
    end
  end
end