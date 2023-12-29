module Manifest
  class Scheduling
    class Simulator

      def initialize
        @dynamo_reader, @dynamo_writer = DynamoHelper.create_reader_and_writer(DEFAULT_DDB_TABLE_NAME)
      end

      def demo_item_data
        [{:event_key=>"fake_evvent_id_1", :report_status=>"initialized"},
          {:event_key=>"fake_evvent_id_2", :report_status=>"initialized"}]
      end

      def demo_put_requests
        {"manifest_delivery_control-production"=>
         [{:put_request=>{:item=>{:event_key=>"fake_evvent_id_1", :report_status=>"initialized"}}},
          {:put_request=>{:item=>{:event_key=>"fake_evvent_id_2", :report_status=>"initialized"}}}]}
      end

      def bad_put_requests
        {{:table_name=>"manifest_delivery_control-production"}=>
          [{:put_request=>{:item=>{:event_key=>"fake_evvent_id_3", :report_status=>"initialized"}}},
          {:put_request=>{:item=>{:event_key=>"fake_evvent_id_4", :report_status=>"initialized"}}}]}
      end

      def scratch
        event_id = "654c5d04-b4c8-47f8-839d-573992144192"
        @dynamo_writer.init_pending_reports([event_id])

        @dynamo_writer.mark_preliminary_sent(event_id)
      end

      def scratch_3
        item_data = [{:event_key=>"fake_evvent_id_1", :report_status=>"initialized"},
        {:event_key=>"fake_evvent_id_2", :report_status=>"initialized"}]

        put_requests = item_data.map do |single_item_data|
          {put_request: { item:single_item_data}   }  
        end
        table_name = 'manifest_delivery_control-production'
          
        request_items = {
          table_name => put_requests
        }

        dynamodb = Aws::DynamoDB::Client.new

        dynamodb.batch_write_item(request_items: request_items)
      end

      def scratch_2
        fake_event_ids = ['fake_evvent_id_1', 'fake_evvent_id_2']

        report_status = Scheduling::CONTROL_INITIALIZED
        table_name = Scheduling::DEFAULT_DDB_TABLE_NAME

        event_ids = fake_event_ids

        item_data = event_ids.map do |event_id|
          {
            event_key: event_id,
            report_status: report_status
          }
        end

        item_data
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

# def dyanmo_insert_jewel_jan_01_prelim
#   event_id = "654c5d04-b4c8-47f8-839d-573992144192"
#   @dynamo_writer.init_pending_reports([event_id])

#   #@dynamo_writer.mark_preliminary_sent(event_id)
# end

# def simulate_read_jewel_jan_01_control_row
#   event_id = "654c5d04-b4c8-47f8-839d-573992144192"

#   @dynamo_reader.fetch_control_rows([event_id])
# end