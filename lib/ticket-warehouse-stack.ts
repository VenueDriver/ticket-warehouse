import * as cdk from 'aws-cdk-lib';
import { Bucket } from 'aws-cdk-lib/aws-s3';
import { Function, Runtime, Code } from 'aws-cdk-lib/aws-lambda';
import { Rule, Schedule } from 'aws-cdk-lib/aws-events';
import { LambdaFunction } from 'aws-cdk-lib/aws-events-targets';
import { Construct } from 'constructs';
import * as events from 'aws-cdk-lib/aws-events';
import * as targets from 'aws-cdk-lib/aws-events-targets';
import * as athena from 'aws-cdk-lib/aws-athena';
import { CfnNamedQuery } from 'aws-cdk-lib/aws-athena';
import { aws_iam as iam } from 'aws-cdk-lib';

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
      },
      timeout: cdk.Duration.seconds(900),  // Set timeout to maximum value
    });
    ticketWarehouseBucket.grantReadWrite(ticketLambda);

    // 3. Set up EventBridge to trigger the Lambda function every 15 minutes
    const ruleForUpcomingEvents = new events.Rule(this, 'RuleForUpcoming', {
      schedule: events.Schedule.rate(cdk.Duration.minutes(15))
    });
    ruleForUpcomingEvents.addTarget(new targets.LambdaFunction(ticketLambda, {
      event: events.RuleTargetInput.fromObject({
        time_range: 'upcoming'
      })
    }));
    
    const ruleForCurrentEvents = new events.Rule(this, 'RuleForCurrent', {
      schedule: events.Schedule.rate(cdk.Duration.hours(24))
    });
    ruleForCurrentEvents.addTarget(new targets.LambdaFunction(ticketLambda, {
      event: events.RuleTargetInput.fromObject({
        time_range: 'current'
      })
    }));

    // 4. Set up AWS Athena to make the data queryable.
    const queryResultsSubfolder = 'athena-query-results/';
    const athenaRole = new iam.Role(this, 'AthenaExecutionRole', {
      assumedBy: new iam.ServicePrincipal('athena.amazonaws.com'),
      inlinePolicies: {
        AthenaS3Access: new iam.PolicyDocument({
          statements: [
            new iam.PolicyStatement({
              actions: [
                "s3:GetObject",
                "s3:PutObject",
                "s3:ListBucket",
                "s3:GetBucketLocation"
              ],
              resources: [ticketWarehouseBucket.bucketArn, `${ticketWarehouseBucket.bucketArn}/*`]
            }),
          ],
        }),
      },
    });
    new athena.CfnWorkGroup(this, 'AthenaWorkGroup', {
      name: 'TicketWarehouse',
      description: 'For the Ticketsauce ticket warehouse',
      recursiveDeleteOption: false,
      state: 'ENABLED',
      workGroupConfiguration: {
        enforceWorkGroupConfiguration: false,
        executionRole: athenaRole.roleArn,
        resultConfiguration: {
          outputLocation: `${ticketWarehouseBucket.s3UrlForObject(queryResultsSubfolder)}`, 
          encryptionConfiguration: {
            encryptionOption: 'SSE_S3' // Server-side encryption using S3-managed keys
          }
        },
        publishCloudWatchMetricsEnabled: false
      }
    });

    new CfnNamedQuery(this, 'AthenaTicketQuery', {
      database: 'ticket_warehouse',
      workGroup: 'TicketWarehouse',
      queryString: `
        CREATE EXTERNAL TABLE IF NOT EXISTS events (
          Event struct<
            active: boolean,
            address: string,
            address2: string,
            city: string,
            country: string,
            created: string,
            custom_id: string,
            show_start: boolean,
            show_end: boolean,
            \`end\`: string,
            end_utc: string,
            featured: boolean,
            id: string,
            latitude: string,
            longitude: string,
            map_zoom: string,
            modified: string,
            online_only: boolean,
            activity_producer_id: string,
            organization_id: string,
            partner_id: string,
            postal_code: string,
            privacy_type: string,
            region: string,
            slug: string,
            start: string,
            start_utc: string,
            state: string,
            tickets_active: boolean,
            timezone: string,
            website: string,
            event_topic_id: string,
            organization_name: string,
            locale: string,
            name: string,
            location: string,
            scheduled_publish_datetime_utc: string,
            event_topic: string,
            category: string,
            event_url: string,
            tickets_url: string,
            display_times: boolean,
            order_count: int
          >,
          Logo struct<
            url: string,
            created: string
          >,
          Masthead struct<
            url: string,
            created: string
          >
        )
        PARTITIONED BY ( 
          venue string,
          year string,
          month string,
          day string
        )
        ROW FORMAT SERDE 'org.openx.data.jsonserde.JsonSerDe'
        STORED AS INPUTFORMAT 'org.apache.hadoop.mapred.TextInputFormat' 
        OUTPUTFORMAT 'org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat'
        LOCATION 's3://${ticketWarehouseBucket.bucketName}/events/'
      `,
      name: 'TicketTableDefinition',
    });
    
  }
}

const app = new cdk.App();
new TicketWarehouseStack(app, 'TicketWarehouseStack');
