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

        def event_id
          self.candidate_event_row.event_id
        end

        #precondition: control_row is present
        def control_with_status?(status)
          self.control_row.report_status == status
        end

        def report_canceled?
          ccontrol_row_present? && control_with_status?(REPORT_CANCELED)
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

