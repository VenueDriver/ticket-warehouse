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
      // Set timeout to maximum value
      timeout: cdk.Duration.seconds(900),
      // Limit concurrency to 1, since the timeout is at the max.
      reservedConcurrentExecutions: 1,
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
    const ruleForUpcomingEvents = new events.Rule(this, 'RuleForUpcoming', {
      schedule: events.Schedule.rate(cdk.Duration.minutes(10))
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

    // 4. Set up AWS Glue to make the data queryable.
    // Create or identify the role
    const glueCrawlerRole = new Role(this, 'GlueCrawlerRole', {
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
    
    const eventsCrawler = new glue.CfnCrawler(this, 'EventsCrawler', {
      databaseName: 'ticket_warehouse',
      role: glueCrawlerRole.roleArn,
      targets: {
        s3Targets: [{
          path: `s3://${ticketWarehouseBucket.bucketName}/events/`
        }]
      },
      name: 'ticket-warehouse-events-crawler',
      tablePrefix: 'ticket_warehouse_',
      schemaChangePolicy: {
        deleteBehavior: 'LOG'
      }
    });

    // Add a crawler for Orders data
    const ordersCrawler = new glue.CfnCrawler(this, 'OrdersCrawler', {
      databaseName: 'ticket_warehouse',
      role: glueCrawlerRole.roleArn,
      targets: {
        s3Targets: [{
          path: `s3://${ticketWarehouseBucket.bucketName}/orders/`
        }]
      },
      name: 'ticket-warehouse-orders-crawler',
      tablePrefix: 'ticket_warehouse_',
      schemaChangePolicy: {
        deleteBehavior: 'LOG'
      }
    });
    
    // Add a crawler for Tickets data
    const ticketsCrawler = new glue.CfnCrawler(this, 'TicketsCrawler', {
      databaseName: 'ticket_warehouse',
      role: glueCrawlerRole.roleArn,
      targets: {
        s3Targets: [{
          path: `s3://${ticketWarehouseBucket.bucketName}/tickets/`
        }]
      },
      name: 'ticket-warehouse-tickets-crawler',
      tablePrefix: 'ticket_warehouse_',
      schemaChangePolicy: {
        deleteBehavior: 'LOG'
      }
    });

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
    const athenaWorkgroup = new athena.CfnWorkGroup(this, 'AthenaWorkGroup', {
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
    
    // Create Athena database
    const athenaDatabase = new athena.CfnNamedQuery(this, 'CreateDatabase', {
      database: 'ticket_warehouse',
      workGroup: 'TicketWarehouse',
      queryString: 'CREATE DATABASE ticket_warehouse',
      name: 'CreateDatabase',
    });
    athenaDatabase.node.addDependency(athenaWorkgroup);
  }
}

const app = new cdk.App();
new TicketWarehouseStack(app, 'TicketWarehouseStack');
