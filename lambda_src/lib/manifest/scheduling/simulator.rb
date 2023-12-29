module Manifest
  class Scheduling
    class Simulator

      def initialize
        @dynamo_reader, @dynamo_writer = DynamoHelper.create_reader_and_writer(DEFAULT_DDB_TABLE_NAME)
      end

      FAKE_EVENT_IDS = ['fake_evvent_id_1', 'fake_evvent_id_2', 'fake_evvent_id_3','fake_evvent_id_4']

      def try_read_fake_event_ids
        fake_event_ids = FAKE_EVENT_IDS

        @dynamo_reader.fetch_control_rows(fake_event_ids)
      end

      def scratch
        cleanup_control_rows
      end

      def cleanup_control_rows
        rows = ['fake_evvent_id_1', 'fake_evvent_id_2']

        rows.each do |row|
          @dynamo_writer.delete_control_row(row)
        end

        recheck = @dynamo_reader.fetch_control_rows(rows)

        puts "recheck: #{recheck}"

      end

      def try_partition_event_ids_by_existence
        fake_event_ids = FAKE_EVENT_IDS

        @dynamo_reader.partition_event_by_exists_and_not_exists(fake_event_ids)
      end
    end
  end
end

# [#<Manifest::Scheduling::CandidateEventRow:0x000000010d7c4620
# @event_date="2024-01-01",
# @event_id="654c5d04-b4c8-47f8-839d-573992144192",
# @event_start_utc_timestamp="2024-01-02 06:30:00.000",
# @event_title="Justin Credible - Flawless Mondays",
# @venue="JEWEL Nightclub">,
# #<Manifest::Scheduling::CandidateEventRow:0x000000010d7c45d0
# @event_date="2024-01-02",
# @event_id="655293b9-089c-4451-8cf2-417f92144192",
# @event_start_utc_timestamp="2024-01-03 06:30:00.000",
# @event_title="Mikey Francis",
# @venue="OMNIA">,
# #<Manifest::Scheduling::CandidateEventRow:0x000000010d7c43f0
# @event_date="2024-01-03",
# @event_id="6551cb54-4fdc-4693-86a8-026a92144192",
# @event_start_utc_timestamp="2024-01-04 06:30:00.000",
# @event_title="LEMA - Lowkey in the Library on Wednesdays",
# @venue="Marquee Nightclub">]

  # def scratch
  #   event_id = "654c5d04-b4c8-47f8-839d-573992144192"
  #   @dynamo_writer.init_pending_reports([event_id])

  #   @dynamo_writer.mark_preliminary_sent(event_id)
  # end