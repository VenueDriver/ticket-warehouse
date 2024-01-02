require_relative 'constants.rb'

module Manifest
  class Scheduling
  
    class DynamoHelperBase
      attr_reader :table_name
      attr_reader :dynamodb

      def initialize(dynamodb ,table_name = DEFAULT_DDB_TABLE_NAME)
        @dynamodb = dynamodb
        @table_name = table_name
        raise "table_name must be a string" unless table_name.is_a? String
        @event_id_factory = EventIdFactory.new(table_name)
      end
    end
    
  end
end