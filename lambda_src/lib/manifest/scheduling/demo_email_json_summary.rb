require_relative '../email_report.rb'

module Manifest
  class Scheduling
    class DemoEmailJsonSummary
      attr_reader :manager, :ses_client
      def initialize(manager)
        @manager = manager
        @ses_client = manager.ses_client
      end

      CurrentAndUpcoming = Struct.new(:current_state, :upcoming_schedule, keyword_init: true) do 
        def joined_hash
          {
            current_state: self.current_state.as_hash,
            upcoming_schedule: self.upcoming_schedule.as_hash
          }
        end
      end

      def create_current_and_upcoming_1030_pm_previews
        current_state = self.manager.preview_schedule_for_now_in_pacific_time
        current_state.optional_description = "Current State"
        upcoming_schedule = self.manager.preview_next_1030PM_pacific_time
        upcoming_schedule.optional_description = "Upcoming Schedule (10:30 PM)"

        CurrentAndUpcoming.new(current_state: current_state, upcoming_schedule: upcoming_schedule)
      end

      def demo_email_json_summary
        ses_client = @ses_client

        current_and_upcoming = self.create_current_and_upcoming_1030_pm_previews

        data_hash = current_and_upcoming.joined_hash

        to_addresses = EmailReport::MARTECH_PLUS_STEPHANE

        formatted_hash = JSON.pretty_generate(data_hash)

        email_body = "Upcoming Manifests Preview:\n\n#{formatted_hash}"
        subject = "Upcoming Manifests Summary Demo" 
        sender = EmailReport::DEFAULT_SENDER

        message = {
          subject: {
            data: subject,
          },
          body: {
            text: {
              data: email_body,
            },
          },
        }

          # Build the email request
        email_request = {
          source: sender,
          destination: {
            to_addresses: to_addresses,
          },
          message: message,
        }

        # Send the email
        begin
          response = ses_client.send_email(email_request)
          puts "Email sent successfully! Message ID: #{response.message_id}"
        rescue Aws::SES::Errors::ServiceError => error
          puts "Error sending email: #{error}"
          error
        end
      end
    end
  end
end