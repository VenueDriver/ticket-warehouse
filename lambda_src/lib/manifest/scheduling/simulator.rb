require 'tzinfo'

module Manifest
  class Scheduling
    require_relative 'report_selector'
    require_relative 'dynamo_helper'

    class Simulator

      def initialize
        @dynamo_reader, @dynamo_writer = DynamoHelper.create_reader_and_writer(DEFAULT_DDB_TABLE_NAME)
      end

      def scratch
        report_selector = ReportSelector.new('production')

        reference_time_in_pst = DateTime.new(2024,1,2,1)

        puts "reference_time_in_pst: #{reference_time_in_pst}"

        tz = TZInfo::Timezone.get('America/Los_Angeles')

        reference_time_in_utc = tz.local_to_utc(reference_time_in_pst)

        puts "reference_time_in_utc: #{reference_time_in_utc}"

        report_selector.select_events(reference_time_in_utc)
      end
 
    end
  end
end
