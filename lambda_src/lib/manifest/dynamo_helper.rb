require 'aws-sdk-dynamodb'

module Manifest
  class DynamoHelper
    DEFAULT_DDB_TABLE_NAME = 'manifest_delivery_control-production'

    class << self

      def initialize_default_row(primary_key, table_name = DEFAULT_DDB_TABLE_NAME)
        # Create a DynamoDB client
        dynamodb = Aws::DynamoDB::Client.new
      
        # Define the default values
        default_values = {
          column_one: 'Your Column One Value here',
          column_two: 'Your Column Two Value here'
        }

        default_values_transformed = default_values.transform_keys { |key| key.to_s }

        item = {'event_key' => primary_key }.merge(default_values_transformed)
      
        # Create a DynamoDB put_item request to initialize the default row
        params = {
          table_name: table_name,
          item: item
        }
      
        begin
          dynamodb.put_item(params)
          puts "Default row initialized for primary key '#{primary_key}' with default values."
        rescue Aws::DynamoDB::Errors::ServiceError => error
          # Handle any errors that may occur during the request
          puts "Error initializing default row for primary key '#{primary_key}': #{error.message}"
        end
      end
      

      def check_records_existence( list_of_primary_keys, table_name:DEFAULT_DDB_TABLE_NAME)
        # Create a DynamoDB client
        dynamodb = Aws::DynamoDB::Client.new
      
        # Check for the existence of each primary key
        results = {}
        
        list_of_primary_keys.each do |primary_key_value|
          params = {
            table_name: table_name,
            key: {
              'event_key' => primary_key_value 
            }
          }
      
          begin
            response = dynamodb.get_item(params)
            exists = !response.item.nil? # Check if the item exists
            
            results[primary_key_value] = exists
          rescue Aws::DynamoDB::Errors::ServiceError => error
            # Handle any errors that may occur during the request
            puts "Error checking existence for primary key #{primary_key_value}: #{error.message}"
          end
        end
      
        results
      end
    end
  end
end

