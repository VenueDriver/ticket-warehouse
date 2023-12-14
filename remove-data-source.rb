require 'aws-sdk-quicksight' # Requires AWS SDK for QuickSight

# Initialize the QuickSight client in 'us-east-1' region
client = Aws::QuickSight::Client.new(region: 'us-east-1')

# Define the AWS account ID and data source name to delete
aws_account_id = "848430332553" # Replace with your AWS account ID
data_source_name = "ticket_warehouse-production"

begin
  # Retrieve the data source ID
  list_data_sources_resp = client.list_data_sources(aws_account_id: aws_account_id)

  puts "Data sources retrieved successfully: #{list_data_sources_resp.data_sources}"

  data_source = list_data_sources_resp.data_sources.find { |ds| ds.name == data_source_name }

  if data_source
    # Delete the data source
    client.delete_data_source(
      aws_account_id: aws_account_id, 
      data_source_id: data_source.data_source_id
    )
    puts "Data source '#{data_source_name}' deleted successfully."
  else
    puts "Data source '#{data_source_name}' not found."
  end
rescue Aws::QuickSight::Errors::ServiceError => e
  # Handle errors
  puts "Failed to delete data source: #{e}"
end
