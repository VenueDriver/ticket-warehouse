require_relative 'constants.rb'

module Manifest
  class Scheduling
  
    class DynamoHelperBase
      attr_reader :table_name
      def initialize(dynamodb ,table_name = DEFAULT_DDB_TABLE_NAME)
        @dynamodb = dynamodb
        @table_name = table_name
      end
    end
    
  end
end