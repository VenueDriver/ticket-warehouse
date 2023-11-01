require 'aws-sdk-quicksight'
require 'aws-sdk-sts'

module Manager
  class Quicksight

    def self.purge
      # Remove all Quicksight resources.
      puts "Purging Quicksight resources..."

      puts "  Account ID: " + account_id
      puts "  Principal user: " + admin_user.user_name

      client = Aws::QuickSight::Client.new(region: 'us-east-1')

      resp = client.list_data_sets({
        aws_account_id: account_id
      })

      resp.data_set_summaries.each do |data_set|
        next unless data_set.name =~ /^ticket\-warehouse/
        puts "  Deleting data set #{data_set.data_set_id}..."
        client.delete_data_set({
          aws_account_id: account_id,
          data_set_id: data_set.data_set_id
        })
      end

      resp = client.list_data_sources({
        aws_account_id: account_id
      })

      resp.data_sources.each do |data_source|
        next unless data_source.name =~ /^ticket\_warehouse/
        puts "  Deleting data source #{data_source.data_source_id}..."
        client.delete_data_source({
          aws_account_id: account_id,
          data_source_id: data_source.data_source_id
        })
      end

    end

    def self.source
      puts "Creating Quicksight data source..."

      puts "  Account ID: " + account_id

      puts "  Principal user: " + admin_user.user_name

      client = Aws::QuickSight::Client.new(region: 'us-east-1')

      resp = client.create_data_source({
        aws_account_id: account_id,
        data_source_id: "ticket_warehouse",
        name: "ticket_warehouse",
        type: 'ATHENA',
        data_source_parameters: {
          athena_parameters: {
            work_group: 'TicketWarehouse'
          }
        },
        permissions: [
          {
            principal: admin_user.arn,
            actions: [
              'quicksight:DescribeDataSource',
              'quicksight:DescribeDataSourcePermissions',
              'quicksight:PassDataSource'
            ]
          }
        ],
        ssl_properties: {
          disable_ssl: false
        }
      })

      puts "  API response: #{resp.inspect}"

      begin
        grant_data_source_permissions(
          data_source_id: "ticket_warehouse",
          user_arn: admin_user.arn)
      rescue Aws::QuickSight::Errors::ConflictException => error
        puts "  Retrying in five seconds after this problem: #{error}"
        sleep 5
        retry
      end
    rescue Aws::QuickSight::Errors::ResourceExistsException => error
      puts "  Data source already exists: #{error}"
    end

    def self.datasets
      
      client = Aws::QuickSight::Client.new(region: 'us-east-1')

      name = 'ticket-warehouse-orders'
      puts "  Creating dataset for query for #{name}..."

      resp = client.create_data_set({
        aws_account_id: account_id,
        data_set_id: name,
        name: name,
        physical_table_map: {
          name => {
            custom_sql: {
              data_source_arn: data_source_arn,
              name: name,
              sql_query: <<~SQL,
                select  tw_orders.venue
                , tw_orders.year
                , tw_orders.month
                , tw_orders.day
                , tw_orders."order".id as order_id
                , tw_orders."order".status as order_status

                , ticket_list.ticket_type_name
                , ticket_list.ticket_type_id
                from ticket_warehouse.ticket_warehouse_orders tw_orders,
                UNNEST(tw_orders."Ticket") as t(ticket_list)
                order by tw_orders."order".id
                limit 6;
              SQL
              columns: [
                { :name => "venue", :type => "STRING" },
                { :name => "year", :type => "STRING" },
                { :name => "month", :type => "STRING" },
                { :name => "day", :type => "STRING" },
                # { :name => "order_id", :type => "STRING" },
                # { :name => "order_status", :type => "STRING" },
                # { :name => "ticket_type_name", :type => "STRING" },
                # { :name => "ticket_type_id", :type => "STRING" }
              ]
            }
          }
        },
        import_mode: "DIRECT_QUERY",
        logical_table_map: {
          name => {
            alias: name,
            source: {
              physical_table_id: name
            }
          }
        }
      })

      puts "  API response: #{resp.inspect}"

      grant_dataset_permissions(dataset_id: name, user_arn: admin_user.arn)

    end

    private

    def self.account_id
      @account_id ||= begin
        sts = Aws::STS::Client.new
        resp = sts.get_caller_identity({})
        resp.account
      end
    end

    def self.admin_user
      return @admin_user if defined?(@admin_user)

      client = Aws::QuickSight::Client.new(region: 'us-east-1')
      
      sts = Aws::STS::Client.new
      resp = sts.get_caller_identity({})
      account_id = resp.account
      
      resp = client.list_users({
        aws_account_id: account_id,
        namespace: 'default'
      })
      
      @admin_user = resp.user_list.
        select{|user| user.user_name =~ /administrator/i }.first.
          tap do |user|
            puts "Admin user: #{user.user_name}, ARN: #{user.arn}"
          end
    end

    def self.data_source_arn
      client = Aws::QuickSight::Client.new(region: 'us-east-1')
      
      resp = client.describe_data_source({
        aws_account_id: account_id,
        data_source_id: "ticket_warehouse"
      })
      
      resp.data_source.arn.tap do |arn|
        puts "Data source ARN: #{arn}"
      end
    end

    def self.grant_dataset_permissions(dataset_id:, user_arn:)
      require 'aws-sdk-quicksight'
      
      client = Aws::QuickSight::Client.new(region: 'us-east-1')
      
      params = {
        aws_account_id: account_id,
        data_set_id: dataset_id,
        grant_permissions: [
          {
            principal: user_arn,
            actions: [
              "quicksight:DeleteDataSet",
              "quicksight:UpdateDataSetPermissions",
              "quicksight:PutDataSetRefreshProperties",
              "quicksight:CreateRefreshSchedule",
              "quicksight:CancelIngestion",
              "quicksight:PassDataSet",
              "quicksight:UpdateRefreshSchedule",
              "quicksight:ListRefreshSchedules",
              "quicksight:DeleteRefreshSchedule",
              "quicksight:DescribeDataSetRefreshProperties",
              "quicksight:DescribeDataSet",
              "quicksight:CreateIngestion",
              "quicksight:DescribeRefreshSchedule",
              "quicksight:ListIngestions",
              "quicksight:DescribeDataSetPermissions",
              "quicksight:UpdateDataSet",
              "quicksight:DeleteDataSetRefreshProperties",
              "quicksight:DescribeIngestion"
            ]
          }
        ]
      }
      
      response = client.update_data_set_permissions(params)
      
      puts response
    end

    def self.grant_data_source_permissions(data_source_id:, user_arn:)
      require 'aws-sdk-quicksight'
      
      client = Aws::QuickSight::Client.new(region: 'us-east-1')
      
      params = {
        aws_account_id: account_id,
        data_source_id: data_source_id,
        grant_permissions: [
          {
            principal: user_arn,
            actions: [
              "quicksight:DescribeDataSource",
              "quicksight:DescribeDataSourcePermissions",
              "quicksight:PassDataSource"
            ]
          }
        ]
      }
      
      response = client.update_data_source_permissions(params)
      
      puts response
    end

  end
end