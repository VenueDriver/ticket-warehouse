require 'aws-sdk-s3'
require 'open3'

module Manager
  class S3

    # Purge the S3 bucket.
    def self.purge_bucket
      puts "Purging S3 bucket..."

      # Initialize S3 client
      client = Aws::S3::Client.new(
        # region: 'us-east-1'
      )

      # Delete all objects in the bucket
      delete_all_objects(client, bucket_name)
    end

    private

    def self.bucket_name
      stdout, stderr, status = Open3.capture3(<<-COMMAND
        aws cloudformation describe-stacks --stack-name TicketWarehouseStack --query "Stacks[0].Outputs[?OutputKey=='BucketNameOutput'].OutputValue" --output text
      COMMAND
      )
      
      unless status.success?
        puts "Error executing aws CLI: #{stderr}"
        return nil
      end

      bucket_name_output = stdout.chomp
    
      if bucket_name_output
        puts "Bucket Name Output: #{bucket_name_output}"
        return bucket_name_output
      else
        puts "Bucket Name Output not found"
        return nil
      end
    end

    def self.delete_all_objects(client, bucket)
      puts "  Deleting all objects in bucket #{bucket}..."

      # List all objects in the bucket
      objects = client.list_objects_v2(bucket: bucket).contents

      # Delete each object
      objects.each do |object|
        puts "    Deleting object #{object.key}..."
        client.delete_object(
          bucket: bucket,
          key: object.key
        )
      end
    end

  end
end
      
