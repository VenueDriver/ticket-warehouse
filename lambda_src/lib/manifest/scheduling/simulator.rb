module Manifest
  class Scheduling
    class Simulator

      def initialize
        @dynamo_reader, @dynamo_writer = DynamoHelper.create_reader_and_writer(DEFAULT_DDB_TABLE_NAME)
      end

 
 
    end
  end
end
