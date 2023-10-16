import * as cdk from 'aws-cdk-lib';
import { Bucket } from 'aws-cdk-lib/aws-s3';
import { Function, Runtime, Code } from 'aws-cdk-lib/aws-lambda';
import { Rule, Schedule } from 'aws-cdk-lib/aws-events';
import { LambdaFunction } from 'aws-cdk-lib/aws-events-targets';
import { CfnNamedQuery } from 'aws-cdk-lib/aws-athena';
import { Construct } from 'constructs';

import * as dotenv from 'dotenv';
dotenv.config();

export class TicketWarehouseStack extends cdk.Stack {
  constructor(scope: Construct, id: string, props?: cdk.StackProps) {
    super(scope, id, props);

    // 1. Create the S3 bucket
    const ticketWarehouseBucket = new Bucket(this, 'TicketWarehouseBucket');

    // 2. Create a Ruby 3.2 Lambda function
    const ticketLambda = new Function(this, 'TicketLambdaFunction', {
      runtime: Runtime.RUBY_3_2,
      code: Code.fromAsset('lambda_src', {
        bundling: {
          image: Runtime.RUBY_3_2.bundlingImage,
          command: [
            'bash', '-c', [
              'bundle install --path /asset-output/vendor/bundle',
              'cp -au . /asset-output/'
            ].join(' && ')
          ],
        }
      }),
      handler: 'handler.lambda_handler',
      environment: {
        'BUCKET_NAME': ticketWarehouseBucket.bucketName,
        'TICKETSAUCE_CLIENT_ID': process.env.TICKETSAUCE_CLIENT_ID || '',
        'TICKETSAUCE_CLIENT_SECRET': process.env.TICKETSAUCE_CLIENT_SECRET || ''
      }
    });

    // 3. Set up EventBridge to trigger the Lambda function every 15 minutes
    const rule = new Rule(this, 'Rule', {
      schedule: Schedule.rate(cdk.Duration.minutes(15))
    });
    rule.addTarget(new LambdaFunction(ticketLambda));

    // 4. Create an AWS Athena table definition
    new CfnNamedQuery(this, 'AthenaTicketQuery', {
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
