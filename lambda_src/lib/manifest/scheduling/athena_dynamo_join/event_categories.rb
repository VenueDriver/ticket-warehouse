require_relative 'join_row.rb'
require_relative 'athena_dynamo_join/event_categories.rb'

module Manifest
  class Scheduling
    class AthenaDynamoJoin

      EventCategories = Struct.new(
        :send_preliminary, 
        :send_final, 
        :final_already_sent, 
        :report_canceled,
        :no_action_waiting_to_send_final, 
        :preliminary_is_not_yet_due, 
        keyword_init: true
      ) do
        
        def convert_to_only_ids
          self.class.new(
            send_preliminary: self.send_preliminary.map(&:event_id),
            send_final: self.send_final.map(&:event_id),
            final_already_sent: self.final_already_sent.map(&:event_id),
            report_canceled: self.report_canceled.map(&:event_id),
            no_action_waiting_to_send_final: self.no_action_waiting_to_send_final.map(&:event_id),
            preliminary_is_not_yet_due: self.preliminary_is_not_yet_due.map(&:event_id) # Renamed key
          )
        end
        
        def self.new_empty
          self.new(
            send_preliminary: [],
            send_final: [],
            final_already_sent: [],
            report_canceled: [],
            no_action_waiting_to_send_final: [],
            preliminary_is_not_yet_due: [] 
          )
        end
      end

    end
  end
end

