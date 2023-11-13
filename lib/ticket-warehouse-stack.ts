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
import * as glue from 'aws-cdk-lib/aws-glue';
import { Role, ServicePrincipal, ManagedPolicy } from 'aws-cdk-lib/aws-iam';

import { TicketWarehouseProps } from './pipeline/ticket-warehouse-deployment-props';

import * as dotenv from 'dotenv';
dotenv.config();

export class TicketWarehouseStack extends cdk.Stack {
  constructor(scope: Construct, id: string, props: TicketWarehouseProps) {
    super(scope, id, props);

    const stage = props.Stage;

    // 1. Create the S3 bucket
    const ticketWarehouseBucket = new Bucket(this, `TicketWarehouseBucket-${stage}`);

    // 2. Create a Ruby 3.2 Lambda function
    const ticketLambda = new Function(this, `TicketLambdaFunction-${stage}`, {
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
      handler: 'Ticketsauce-API-ETL-handler.lambda_handler',
      environment: {
        'BUCKET_NAME': ticketWarehouseBucket.bucketName,
        'TICKETSAUCE_CLIENT_ID': process.env.TICKETSAUCE_CLIENT_ID || '',
        'TICKETSAUCE_CLIENT_SECRET': process.env.TICKETSAUCE_CLIENT_SECRET || ''
      },
      // Set timeout to maximum value
      timeout: cdk.Duration.seconds(900),
      // Limit concurrency to 1, since the timeout is at the max.
      reservedConcurrentExecutions: 2,
      memorySize: 1024,
    });
    ticketWarehouseBucket.grantReadWrite(ticketLambda);

    ticketLambda.addToRolePolicy(new iam.PolicyStatement({
      actions: [
        'athena:GetNamedQuery',
        'athena:ListNamedQueries',
        'athena:StartQueryExecution',
        'athena:GetQueryExecution',
        'glue:CreateDatabase',
        'glue:CreateTable',
        'glue:startCrawler',
      ],
      resources: ['*'],
    }));

    // 3. Set up EventBridge to trigger the Lambda function periodically.
    const ruleForUpcomingEvents = new events.Rule(this, `RuleForUpcoming-${stage}`, {
      schedule: events.Schedule.rate(cdk.Duration.hours(1))
    });
    ruleForUpcomingEvents.addTarget(new targets.LambdaFunction(ticketLambda, {
      event: events.RuleTargetInput.fromObject({
        time_range: 'upcoming'
      })
    }));
    
    const ruleForCurrentEvents = new events.Rule(this, `RuleForCurrent-${stage}`, {
      schedule: events.Schedule.rate(cdk.Duration.minutes(5))
    });
    ruleForCurrentEvents.addTarget(new targets.LambdaFunction(ticketLambda, {
      event: events.RuleTargetInput.fromObject({
        time_range: 'current'
      })
    }));

    // 4. Create a separate Lambda function to trigger the Glue crawler.
    // (It's too slow and expensive to run it every time the data updates.)
    const glueCrawlerLambda = new Function(this, `GlueCrawlerLambdaFunction-${stage}`, {
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
      handler: 'Glue-crawler-handler.lambda_handler',
      environment: {
        'GLUE_CRAWLER_NAME': 'YOUR_GLUE_CRAWLER_NAME'
      },
      timeout: cdk.Duration.minutes(5),
      memorySize: 1024,
    });
    
    // Give this Lambda function permission to start the Glue Crawler
    glueCrawlerLambda.addToRolePolicy(new iam.PolicyStatement({
      actions: ['glue:StartCrawler'],
      resources: ['*']
    }));
    
    // 5. Set up EventBridge to trigger the Glue Crawler Lambda function once a day
    
    const dailyGlueCrawlerRule = new events.Rule(this, `DailyGlueCrawlerTrigger-${stage}`, {
      schedule: events.Schedule.cron({ 
        minute: '0', 
        hour: '0' 
      })  // This will run at 12:00 AM daily
    });
    
    dailyGlueCrawlerRule.addTarget(new targets.LambdaFunction(glueCrawlerLambda));
    
    // 6. Set up AWS Glue to make the data queryable.
    // Create or identify the role
    const glueCrawlerRole = new Role(this, `GlueCrawlerRole-${stage}`, {
      assumedBy: new ServicePrincipal('glue.amazonaws.com'),
    });
    
    // Attach necessary permissions to the role
    glueCrawlerRole.addToPolicy(new iam.PolicyStatement({
      actions: [
        'logs:CreateLogGroup',
        'logs:CreateLogStream',
        'logs:PutLogEvents',
        'glue:GetDatabase',
        'glue:GetTable',
        'glue:GetTables',
        'glue:UpdateDatabase',
        'glue:UpdateTable',
        'glue:CreateDatabase',
        'glue:CreateTable',
        'glue:DeleteDatabase',
        'glue:DeleteTable',
        'glue:CreatePartition',
        'glue:GetPartition',
        'glue:UpdatePartition',
        'glue:DeletePartition',
        'glue:BatchGetPartition',
        'glue:BatchCreatePartition'
      ],
      resources: ['*'],  // This gives permissions to all log groups. Narrow this down if necessary.
    }));
        
    glueCrawlerRole.addToPolicy(new iam.PolicyStatement({
      actions: ['s3:GetObject', 's3:ListBucket'],
      resources: [ticketWarehouseBucket.bucketArn, `${ticketWarehouseBucket.bucketArn}/*`]
    }));

    const queryResultsSubfolder = 'athena-query-results/';
    const athenaRole = new iam.Role(this, `AthenaExecutionRole-${stage}`, {
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
    const athenaWorkgroup = new athena.CfnWorkGroup(this, `AthenaWorkGroup-${stage}`, {
      name: `TicketWarehouse-${stage}`,
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
    
    // Create Athena database
    const athenaDatabase = new athena.CfnNamedQuery(this, `CreateDatabase-${stage}`, {
      database: `ticket_warehouse-${stage}`,
      workGroup: athenaWorkgroup.name,
      queryString: `CREATE DATABASE ticket_warehouse-${stage}`,
      name: 'CreateDatabase',
    });
    athenaDatabase.node.addDependency(athenaWorkgroup);
    
    const eventsCrawler = new glue.CfnCrawler(this, `EventsCrawler-${stage}`, {
      databaseName: athenaDatabase.database,
      role: glueCrawlerRole.roleArn,
      targets: {
        s3Targets: [{
          path: `s3://${ticketWarehouseBucket.bucketName}/events/`
        }]
      },
      name: `ticket-warehouse-events-${stage}`,
      tablePrefix: 'ticket_warehouse_',
      schemaChangePolicy: {
        deleteBehavior: 'LOG'
      }
    });

    // Add a crawler for Orders data
    const ordersCrawler = new glue.CfnCrawler(this, `OrdersCrawler-${stage}`, {
      databaseName: athenaDatabase.database,
      role: glueCrawlerRole.roleArn,
      targets: {
        s3Targets: [{
          path: `s3://${ticketWarehouseBucket.bucketName}/orders/`
        }]
      },
      name: `ticket-warehouse-orders-${stage}`,
      tablePrefix: 'ticket_warehouse_',
      schemaChangePolicy: {
        deleteBehavior: 'LOG'
      }
    });
    
    // Add a crawler for Tickets data
    const ticketsCrawler = new glue.CfnCrawler(this, `TicketsCrawler-${stage}`, {
      databaseName: athenaDatabase.database,
      role: glueCrawlerRole.roleArn,
      targets: {
        s3Targets: [{
          path: `s3://${ticketWarehouseBucket.bucketName}/tickets/`
        }]
      },
      name: `ticket-warehouse-tickets-${stage}`,
      tablePrefix: 'ticket_warehouse_',
      schemaChangePolicy: {
        deleteBehavior: 'LOG'
      }
    });

    // Add a crawler for Ticket Types data
    const ticketTypesCrawler = new glue.CfnCrawler(this, `TicketTypesCrawler-${stage}`, {
      databaseName: athenaDatabase.database,
      role: glueCrawlerRole.roleArn,
      targets: {
        s3Targets: [{
          path: `s3://${ticketWarehouseBucket.bucketName}/ticket_types/`
        }]
      },
      name: `ticket-warehouse-ticket-types-${stage}`,
      tablePrefix: 'ticket_warehouse_',
      schemaChangePolicy: {
        deleteBehavior: 'LOG'
      }
    });
    
    // Add a crawler for Checkin IDs data
    const checkinIDsCrawler = new glue.CfnCrawler(this, `CheckinIDsCrawler-${stage}`, {
      databaseName: athenaDatabase.database,
      role: glueCrawlerRole.roleArn,
      targets: {
        s3Targets: [{
          path: `s3://${ticketWarehouseBucket.bucketName}/checkin_ids/`
        }]
      },
      name: `ticket-warehouse-checkin-ids-${stage}`,
      tablePrefix: 'ticket_warehouse_',
      schemaChangePolicy: {
        deleteBehavior: 'LOG'
      }
    });

    // Add a crawler for Stripe data
    const stripeChargesCrawler = new glue.CfnCrawler(this, `StripeChargesCrawler-${stage}`, {
      databaseName: athenaDatabase.database,
      role: glueCrawlerRole.roleArn,
      targets: {
        s3Targets: [{
          path: `s3://${ticketWarehouseBucket.bucketName}/stripe_charges/`
        }]
      },
      name: `ticket-warehouse-stripe-charges-${stage}`,
      tablePrefix: 'ticket_warehouse_',
      schemaChangePolicy: {
        deleteBehavior: 'LOG'
      }
    });
    
    /////////////
    // Outputs
    
    new cdk.CfnOutput(this, 'BucketNameOutput', {
      value: ticketWarehouseBucket.bucketName,
      description: 'The name of the Ticket Warehouse S3 bucket',
      exportName: `TicketWarehouseBucketName-${stage}`,
    });

  }
}

const app = new cdk.App();
//new TicketWarehouseStack(app, 'TicketWarehouseStack');
