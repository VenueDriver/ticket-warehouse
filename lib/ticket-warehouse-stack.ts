import * as cdk from '@aws-cdk/core';
import * as s3 from '@aws-cdk/aws-s3';
import * as lambda from '@aws-cdk/aws-lambda';
import * as events from '@aws-cdk/aws-events';
import * as targets from '@aws-cdk/aws-events-targets';
import * as athena from '@aws-cdk/aws-athena';

export class TicketWarehouseStack extends cdk.Stack {
  constructor(scope: cdk.Construct, id: string, props?: cdk.StackProps) {
    super(scope, id, props);

    // 1. Create the S3 bucket
    const ticketWarehouseBucket = new s3.Bucket(this, 'TicketWarehouseBucket');

    // 2. Create a Ruby 3.2 Lambda function
    const ticketLambda = new lambda.Function(this, 'TicketLambdaFunction', {
      runtime: lambda.Runtime.RUBY_3_2,
      code: lambda.Code.fromAsset('lambda_src', {
        bundling: {
          image: lambda.Runtime.RUBY_3_2.bundlingImage,
          command: [
            'bash', '-c', [
              'bundle install --path /asset-output/vendor/bundle',
              'cp -au . /asset-output/'
            ].join(' && ')
          ],
        }
      }),
      handler: 'handler.lambda_handler'
      environment: {
          'BUCKET_NAME': ticketWarehouseBucket.bucketName
        }
    });

    // 3. Set up EventBridge to trigger the Lambda function every 15 minutes
    const rule = new events.Rule(this, 'Rule', {
      schedule: events.Schedule.rate(cdk.Duration.minutes(15))
    });
    rule.addTarget(new targets.LambdaFunction(ticketLambda));

    // 4. Create an AWS Athena table definition
    new athena.CfnNamedQuery(this, 'AthenaTicketQuery', {
      database: 'your_database_name',  // Change to your Athena database name
      queryString: `
        CREATE EXTERNAL TABLE IF NOT EXISTS ticket_table (
          // Define your table columns here, e.g., id STRING, name STRING, etc.
        )
        ROW FORMAT DELIMITED 
        FIELDS TERMINATED BY ',' 
        STORED AS TEXTFILE
        LOCATION 's3://${ticketWarehouseBucket.bucketName}/your_folder_name/'
      `,
      name: 'TicketTableDefinition',
    });
  }
}

const app = new cdk.App();
new TicketWarehouseStack(app, 'TicketWarehouseStack');
