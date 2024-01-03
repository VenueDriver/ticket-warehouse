module Manifest
  class Scheduling
    class ControlRow
      def initialize(raw_dynamo_result)
        @raw_dynamo_result = raw_dynamo_result
      end

      def event_id
        @raw_dynamo_result["event_key"]
      end

      def report_status
        @raw_dynamo_result["report_status"]
      end

      def self.map_to_list(list)
        list.map do |list_item|
          self.new(list_item)
        end
      end

      # example
      # [{"event_key"=>"fake_evvent_id_1", "report_status"=>"initialized"},
      #  {"event_key"=>"fake_evvent_id_2", "report_status"=>"initialized"}]
    end
  end
end