
module Manifest
  class Scheduling
    class PreviewSchedule

      SummaryStruct = Struct.new(
        :optional_description,
        :preliminary_cutoff_utc, 
        :final_cutoff_utc,
        :preliminary_reports, :final_reports, :canceled_reports, 
        
        :prelim_cutoff_in_local_time,
        :preliminary_is_not_yet_due,

        :final_cutoff_in_local_time,
        :no_action_waiting_to_send_final,
        
        :final_already_sent,

        :reference_time_in,
        keyword_init: true) do
          def as_hash
            start = {
              optional_description: self.optional_description,
              preliminary_cutoff_local: self.prelim_cutoff_in_local_time,
              final_cutoff_local: self.final_cutoff_in_local_time
            }
            
            rest = to_h.transform_keys(&:to_sym).except(:optional_description, :preliminary_cutoff_local, :final_cutoff_local)
            start.merge(rest)
          end
        end
        
    end
  end
end