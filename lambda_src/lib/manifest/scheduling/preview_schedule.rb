require 'tzinfo'
require_relative 'preview_schedule/summary_struct.rb'

module Manifest
  class Scheduling
    class PreviewSchedule
      def initialize(categorized_join_rows)
        # from ReportSelector#select_events
        # EventCategories struct like object
        @categorized_join_rows = categorized_join_rows
      end

      def summary_struct
        values = self.report_exec_preview_hash

        SummaryStruct.new(**values)
      end

      def report_exec_preview_hash
        prelim_cutoff_utc = @categorized_join_rows.preliminary_cutoff_utc
        final_cutoff_utc = @categorized_join_rows.final_cutoff_utc

        prelim_cutoff_utc_str = prelim_cutoff_utc.strftime("%F %T") 
        final_cutoff_utc_str = final_cutoff_utc.strftime("%F %T")

        inspect_hash_categories = @categorized_join_rows.convert_to_join_row_inspect_hash # hashes, this is a struct
      
        reference_time_utc = inspect_hash_categories.reference_time.strftime("%F %T")
        
        preliminary_is_not_yet_due = @categorized_join_rows.preliminary_is_not_yet_due.map(&:abbreviated_summary)
        no_action_waiting_to_send_final= @categorized_join_rows.no_action_waiting_to_send_final.map(&:abbreviated_summary)

        pacific_time_zone = TZInfo::Timezone.get('America/Los_Angeles')

        prelim_cutoff_in_local_time  = pacific_time_zone.utc_to_local(prelim_cutoff_utc)
        final_cutoff_in_local_time  = pacific_time_zone.utc_to_local(final_cutoff_utc)

        prelim_cutoff_in_local_time_str = prelim_cutoff_in_local_time.strftime("%F %R")
        final_cutoff_in_local_time_str = final_cutoff_in_local_time.strftime("%F %R")
        #final_already_sent: self.final_already_sent.map(&mapping_fn),
        final_already_sent = @categorized_join_rows.final_already_sent.map(&:abbreviated_summary)
        {
          preliminary_cutoff_utc: prelim_cutoff_utc_str,
          
          final_cutoff_utc: final_cutoff_utc_str,
          reference_time_in: reference_time_utc,
          preliminary_reports: inspect_hash_categories.send_preliminary,
          final_reports: inspect_hash_categories.send_final,
          canceled_reports: inspect_hash_categories.report_canceled,
          prelim_cutoff_in_local_time: prelim_cutoff_in_local_time_str,
          preliminary_is_not_yet_due: preliminary_is_not_yet_due,
          
          final_cutoff_in_local_time: final_cutoff_in_local_time_str,
          no_action_waiting_to_send_final: no_action_waiting_to_send_final,
          
          final_already_sent: final_already_sent,
        }
      end
    end
  end
end