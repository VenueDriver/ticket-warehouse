require_relative '../../athena-manager.rb'
require_relative 'dev_query.rb'

module Manifest
  class EventDataFetcher
    attr_reader :athena_manager, :query_builder, :last_query_result
    def initialize(env_in)
      @athena_manager = AthenaManager.new(env_in)
      @athena_manager.use_array_of_hashes_formatter!
      @query_builder = DevQuery.new
    end

    def fetch_data_from_athena(event_id)
      query_string = @query_builder.on_event_id(event_id)
      r = @athena_manager.start_query(query_string: query_string)
      @last_query_result = r
      r
    end
  end
end