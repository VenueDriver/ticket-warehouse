require 'byebug'

module Manifest
  class Scheduling
    class Jan2024WeekOne

      def initialize
        @manager = Scheduling.create_manager
        @delivery_bookkeeper = @manager.delivery_bookkeeper
        @report_performer = @manager.report_performer
        @report_performer.limit_final_reports_to_one_at_a_time!
      end

      def reset_all_finals!
        jan_04_final_ids.each do |event_id|
          @delivery_bookkeeper.single_force_reset_to_preliminary_sent(event_id)
        end
      end

      def simulate_10_35_pm(just_preview: true)
        reference_time = DateTime.new(2024, 1, 4, 22, 35)
        converted_to_utc = @manager.convert_to_utc(reference_time)
        puts "converted_to_utc: #{converted_to_utc}"

        if just_preview
          r = @manager.create_demo_email_summary_json_soft_launch
          pp r
          r
        else
          @manager.process_main_report_schedule_using(converted_to_utc)
        end

      end

      def jan_04_final_ids
        ["654da5d9-4740-4b01-ad17-4eef92144192", 
        "654d5808-d84c-445e-a869-706692144192", 
        "65529598-5810-4684-81c5-443492144192"]
      end

      def jan_04_prelim_ids
        ["654c60c4-7f04-4267-9e82-5a7a92144192",
          "654da86d-4c14-43d5-aa65-52e692144192",
          "6551ce24-282c-4761-a327-026a92144192",
          "654d7ab9-6d9c-4b90-9f1b-1ae492144192",
          "655297f0-7e68-4e36-9911-515c92144192"]
      end
    end
  end
end