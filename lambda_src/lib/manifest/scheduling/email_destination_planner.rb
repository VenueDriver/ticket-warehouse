require_relative '../distribution_list.rb'
require_relative '../email_report.rb'

module Manifest
  class Scheduling

    SenderAndDestinations = Struct.new(:sender, :to_addresses)

    class PlannerBase
      def initialize
        @sender_email_address = EmailReport::DEFAULT_SENDER
      end

      def form_with_sender(to_addresses)
        to_addresses = Array(to_addresses)
        SenderAndDestinations.new(@sender_email_address, to_addresses)
      end
    end

    class AlwaysMartech < PlannerBase
      def initialize
        @to_addresses = Manifest::EmailReport::MARTECH_PLUS_STEPHANE
        super
      end

      def preliminary(email_report)
        form_with_sender(@to_addresses)
      end

      def final(email_report)
        form_with_sender(@to_addresses)
      end

      def accounting(email_report)
        form_with_sender(@to_addresses)
      end
    end

    class UsingDistributionList < PlannerBase
      def preliminary(email_report)
        form_with_sender(Manifest::EmailReport::MARTECH_PLUS_STEPHANE)
      end

      def final(email_report)
        raise "Not implemented"
        #lookup distro partner from venue name
        venue = email_report.venue_from_output_structs
        distro_mapping = Manifest::DistributionList.production_mapping
        to_address = distro_mapping.fetch(venue)
        form_with_sender(to_address)
      end

      def accounting(email_report)
        dest = Manifest::EmailReport::ACCOUNT_PRODUCTION_DESTINATION
        form_with_sender(dest)
      end 
    end


  end
end