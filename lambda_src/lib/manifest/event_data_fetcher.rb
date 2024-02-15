require_relative '../../athena-manager.rb'
require_relative 'dev_query.rb'
require_relative 'scheduling/dynamo_helper.rb' # Import the DynamoWriter class

module Manifest
  class EventDataFetcher
    attr_reader :athena_manager, :query_builder, :last_query_result
    def initialize(env_in)
      @athena_manager = AthenaManager.new(env_in)
      @athena_manager.use_array_of_hashes_formatter!
      @query_builder = DevQuery.new
      @dynamo_writer = Manifest::Scheduling::DynamoWriter.new # Initialize an instance of DynamoWriter
    end

    def fetch_data_from_athena(event_id)
      query_string = @query_builder.on_event_id(event_id)
      begin
        r = @athena_manager.start_query(query_string: query_string)
        @last_query_result = r
        r
      rescue => e
        # Log the error
        puts "Error occurred: #{e.message}"
        # Assuming there's a method or an instance variable to mark the event as preliminary sent
        @dynamo_writer.mark_preliminary_sent(event_id)
        # Return a default value or handle the error as needed
        return []
      end
    end
  end
end