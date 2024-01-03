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
        # preliminary_cutoff_utc, final_cutoff_utc

        :preliminary_cutoff_utc, :final_cutoff_utc,
        keyword_init: true
      ) do
        
        def convert_to_only_ids
          self.convert_with_mapping_fn do |join_row|
            join_row.event_id
          end
        end

        def convert_to_join_row_inspect_hash
          # inspect_hash
          self.convert_with_mapping_fn do |join_row|
            join_row.inspect_hash
          end
        end

        def convert_with_mapping_fn(&mapping_fn)
          self.class.new(
            send_preliminary: self.send_preliminary.map(&mapping_fn),
            send_final: self.send_final.map(&mapping_fn),
            final_already_sent: self.final_already_sent.map(&mapping_fn),
            report_canceled: self.report_canceled.map(&mapping_fn),
            no_action_waiting_to_send_final: self.no_action_waiting_to_send_final.map(&mapping_fn),
            preliminary_is_not_yet_due: self.preliminary_is_not_yet_due.map(&mapping_fn), # Renamed key
            preliminary_cutoff_utc: self.preliminary_cutoff_utc,
            final_cutoff_utc: self.final_cutoff_utc
          )
        end
        
        def self.new_empty(preliminary_cutoff_utc:, final_cutoff_utc:)
          self.new(
            send_preliminary: [],
            send_final: [],
            final_already_sent: [],
            report_canceled: [],
            no_action_waiting_to_send_final: [],
            preliminary_is_not_yet_due: [] ,
            preliminary_cutoff_utc: preliminary_cutoff_utc,
            final_cutoff_utc: final_cutoff_utc
          )
        end
      end

    end
  end
end

