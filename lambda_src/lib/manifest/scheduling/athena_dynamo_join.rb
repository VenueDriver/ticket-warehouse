require_relative 'athena_dynamo_join/join_row.rb'
require_relative 'athena_dynamo_join/event_categories.rb'

module Manifest
  class Scheduling
    class AthenaDynamoJoin

      def initialize(athena_rows, dynamo_rows)
        @athena_rows = athena_rows
        @dynamo_rows = dynamo_rows
        @lookup_table = Hash.new

        self.show_class_of_first_item_in_each_list

        self.prepare_lookup_table
      end

      def show_class_of_first_item_in_each_list
        first_athena = @athena_rows.first
        first_dynamo = @dynamo_rows.first
        h = {first_athena: first_athena.class.to_s, first_dynamo: first_dynamo.class.to_s}

        puts "AthenaDynamoJoin: input row types: #{h}"
      end

      # EventCategories = Struct.new(
      #   :send_preliminary, 
      #   :send_final, 
      #   :final_already_sent, 
      #   :report_canceled,
      #   :no_action_waiting_to_send_final, 
      #   :preliminary_is_not_yet_due, 

      def categorize(preliminary_cutoff_utc, final_cutoff_utc)
        event_categories = 
          EventCategories.new_empty(preliminary_cutoff_utc: preliminary_cutoff_utc, final_cutoff_utc: final_cutoff_utc)

        if preliminary_cutoff_utc.nil? || final_cutoff_utc.nil?
          raise StandardError.new("preliminary_cutoff_utc and final_cutoff_utc must be non-nil")
        end
        
        all_join_rows.each do |join_row|
          if join_row.report_canceled?
            event_categories.report_canceled << join_row
          elsif join_row.final_already_sent?
            event_categories.final_already_sent << join_row
          elsif join_row.prelim_sent?
            if join_row.within_cutoff?(final_cutoff_utc)
              event_categories.send_final << join_row
            else
              event_categories.no_action_waiting_to_send_final << join_row
            end
            #needs_preliminary?  doesn't check the start time
          elsif join_row.needs_preliminary?
            if join_row.within_cutoff?(preliminary_cutoff_utc)
              event_categories.send_preliminary << join_row
            else 
              event_categories.preliminary_is_not_yet_due << join_row
            end
          end

        end
        event_categories
      end

      def all_join_rows
        @lookup_table.values
      end

      private

      def prepare_lookup_table
        @lookup_table = Hash.new
        # Given: we expect dynamo_rows to be a subset of athena_rows
        # They are logically equivalent to a REPORT_INITIALIZED status
        # We are doing a hash join on event_id using ruby hashes
        
        #byebug
        @athena_rows.each do |athena_row|
          @lookup_table[athena_row.event_id] = JoinRow.new(athena_row, nil)
        end

        @dynamo_rows.each do |dynamo_row|
          lookup_result = @lookup_table.fetch(dynamo_row.event_id,:not_found)

          if :not_found == lookup_result
            #log a warning 
            # skip to next row
            next 
          end

          lookup_result.control_row = dynamo_row
        end
        @lookup_table
      end
    end
  end
end

