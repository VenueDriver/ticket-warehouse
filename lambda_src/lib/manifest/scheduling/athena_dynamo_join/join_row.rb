module Manifest
  class Scheduling
    class AthenaDynamoJoin

      JoinRow = Struct.new(:candidate_event_row, :control_row) do
        def control_row_not_present?
          self.control_row.nil?
        end

        def control_row_present?
          !self.control_row_not_present?
        end

        def inspect_hash
          candidate_event_row_summary = self.candidate_event_row.summary_for_join_row_inspect

          candidate_event_row_summary.merge(
            control_row_status_abstract: self.control_row_status_abstract,
            report_status_raw: self.report_status_raw,
          )
        end

        def control_row_status_abstract
          # without the cutoffs we can only show eligibility
          if needs_preliminary? 
            :eligible_for_preliminary
          elsif report_canceled?
            :report_canceled
          elsif final_already_sent?
            :final_already_sent
          elsif prelim_sent?
            :eligible_for_final
          else
            :unknown
          end
        end

        def report_status_raw
          if control_row_not_present?
            CONTROL_ROW_DOES_NOT_EXIST # 'control_row_does_not_exist'
          else
            self.control_row.report_status
          end
        end

        def event_id
          self.candidate_event_row.event_id
        end

        #precondition: control_row is present
        def control_with_status?(status)
          self.control_row.report_status == status
        end

        def report_canceled?
          control_row_present? && control_with_status?(REPORT_CANCELED)
        end

        def final_already_sent?
          control_row_present? && control_with_status?(FINAL_SENT)
        end

        def prelim_sent?
          control_row_present? && control_with_status?(PRELIM_SENT)
        end

        def needs_preliminary? # eligible for prelim
          control_row_not_present? || control_with_status?(CONTROL_INITIALIZED)
        end

        def within_cutoff?(cutoff_timestamp_utc)
          event_start_utc = self.candidate_event_row.event_start_utc_timestamp_parsed
          event_start_utc <= cutoff_timestamp_utc
        end
      end

    end
  end
end

