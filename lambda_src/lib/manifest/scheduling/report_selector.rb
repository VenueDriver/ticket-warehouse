require_relative 'candidate_event_reader.rb'
require_relative 'dynamo_helper.rb'


module Manifest
  class Scheduling 

    class ReportSelector 
      def initialize(env_in = ENV['ENV'])
        @athena_reader = CandidateEventReader.new(env_in)

        @dynamo_db_client = Aws::DynamoDB::Client.new
        table_name = DEFAULT_DDB_TABLE_NAME
        @dynamo_reader = DynamoReader.new(@dynamo_db_client, table_name)
        
        # writer not used currently 
        @dynamo_writer = DynamoWriter.new(@dynamo_db_client, table_name)
      end
  
      # - Input: reference_time, defaults to now
      # - Output: Categorized list of event ids 
      def select_events(reference_time = DateTime.now )
        timestamp_tupple = window_from_reference_time(reference_time)

        from_athena = @athena_reader.fetch_event_data(timestamp_tupple.start_time, timestamp_tupple.end_time )

        candidate_rows  = CandidateEventRow.transform_event_rows(from_athena)

        candidate_event_ids = candidate_rows.map(&:event_id)

        control_rows = @dynamo_reader.fetch_control_rows(candidate_event_ids)

        athena_dynamo_join = AthenaDynamoJoin.new(candidate_rows, control_rows)

        prelim_cutoff_utc = timestamp_tupple.prelim_cutoff_utc
        final_cutoff_utc = timestamp_tupple.final_cutoff_utc

        athena_dynamo_join.categorize(prelim_cutoff_utc, final_cutoff_utc)
      end

      TimestampTupple = Struct.new(:start_time, :end_time, 
        :final_cutoff_utc, :prelim_cutoff_utc, 
        keyword_init:true)

      private 

      def window_from_reference_time(reference_time)
        reference_time = reference_time.to_datetime

        start_time = reference_time - 2.0
        end_time = reference_time + 2.0
        final_cutoff_utc = reference_time
        prelim_cutoff_utc = reference_time + 1.0

        TimestampTupple.new(
          start_time: start_time, 
          end_time: end_time,
          final_cutoff_utc: final_cutoff_utc, 
          prelim_cutoff_utc: prelim_cutoff_utc
        )

      end
    end
  end
end

