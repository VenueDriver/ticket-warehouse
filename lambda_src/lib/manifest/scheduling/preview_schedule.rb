module Manifest
  class Scheduling
    class PreviewSchedule
      def initialize(categorized_join_rows)
        # from ReportSelector#select_events
        # EventCategories struct like object
        @categorized_join_rows = categorized_join_rows
      end

      SummaryStruct = Struct.new(:preliminary_cutoff_utc, :final_cutoff_utc,
        :preliminary_reports, :final_reports, :canceled_reports, keyword_init: true)
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
      
        {
          preliminary_cutoff_utc: prelim_cutoff_utc_str,
          final_cutoff_utc: final_cutoff_utc_str,
          preliminary_reports: inspect_hash_categories.send_preliminary,
          final_reports: inspect_hash_categories.send_final,
          canceled_reports: inspect_hash_categories.report_canceled,
        }
      end
    end
  end
end