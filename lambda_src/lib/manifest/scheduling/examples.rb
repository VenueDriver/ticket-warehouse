module Manifest
  class Scheduling
    class Examples

      def initialize
        @dynamo_reader, @dynamo_writer = DynamoHelper.create_reader_and_writer(DEFAULT_DDB_TABLE_NAME)
      end

      FAKE_EVENT_IDS_1 = ['fake_evvent_id_1', 'fake_evvent_id_2']
      FAKE_EVENT_IDS_2 = ['fake_evvent_id_1', 'fake_evvent_id_2', 'fake_evvent_id_3','fake_evvent_id_4']


      def scratch
        mock_prelim_sent
      end

      def mock_cancel_report
        cleanup_control_rows
        mock_prelim_sent

        event_ids = FAKE_EVENT_IDS_1

        recheck_rows(event_ids, '3')

        cancel_event_id = event_ids.first

        @dynamo_writer.cancel_report(cancel_event_id)

        recheck_rows(event_ids, '4')
        #r
      end

      def mock_final_sent
        #precondition: we do the steps in 'mock_prelim_sent'
        cleanup_control_rows
        mock_prelim_sent

        puts "sleeping for 5"
        sleep(5)

        event_ids = FAKE_EVENT_IDS_1

        event_ids.each do |event_id|
          @dynamo_writer.mark_final_sent(event_id)
        end

        recheck = @dynamo_reader.fetch_control_rows(event_ids)

        puts "after_final: #{recheck}"
      end

      def mock_prelim_sent
        event_ids = FAKE_EVENT_IDS_1

        r = @dynamo_writer.init_pending_reports(event_ids)

        recheck = @dynamo_reader.fetch_control_rows(event_ids)
        puts "recheck1: #{recheck}"

        event_ids.each do |event_id|
          @dynamo_writer.mark_preliminary_sent(event_id)
        end

        recheck = @dynamo_reader.fetch_control_rows(event_ids)

        puts "recheck2: #{recheck}"
      end

      ##########################################

      def cleanup_control_rows
        rows = FAKE_EVENT_IDS_1

        rows.each do |row|
          @dynamo_writer.delete_control_row(row)
        end

        recheck = @dynamo_reader.fetch_control_rows(rows)

       # puts "recheck: #{recheck}"
      end

      def try_partition_event_ids_by_existence
        fake_event_ids = FAKE_EVENT_IDS_2

        @dynamo_reader.partition_event_by_exists_and_not_exists(fake_event_ids)
      end

      def try_read_fake_event_ids
        fake_event_ids = FAKE_EVENT_IDS_1

        @dynamo_reader.fetch_control_rows(fake_event_ids)
      end

      private

      def recheck_rows(event_ids, label='1')
        recheck = @dynamo_reader.fetch_control_rows(event_ids)
        puts "recheck_#{label}: #{recheck}"
      end
    end
  end
end
