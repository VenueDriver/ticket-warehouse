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

    // 1. Create the S3 buckets
    const ticketWarehouseBucket = new Bucket(this, `TicketWarehouseBucket-${stage}`);
    const vaultBucket = new Bucket(this, `VaultArchiveBucket-${stage}`);

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
        'athena:GetQueryResults',
        'glue:GetDatabase',
        'glue:CreateDatabase',
        'glue:CreateTable',
        'glue:GetTable',
        'glue:GetPartitions',
        'glue:BatchCreatePartition',
        'glue:startCrawler',
        'ssm:GetParameter'
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

    glueCrawlerRole.addToPolicy(new iam.PolicyStatement({
      actions: ['s3:GetObject', 's3:ListBucket'],
      resources: [vaultBucket.bucketArn, `${vaultBucket.bucketArn}/*`]
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
              resources: [
                ticketWarehouseBucket.bucketArn, 
                `${ticketWarehouseBucket.bucketArn}/*`,
                vaultBucket.bucketArn,
                `${vaultBucket.bucketArn}/*`
              ]
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
    
    function createCrawler(scope: Construct, stage: string, bucketName: string, tableName: string, tablePrefix: string): glue.CfnCrawler {
      return new glue.CfnCrawler(scope, `Crawler-${stage}-${tableName}`, {
        databaseName: athenaDatabase.database,
        role: glueCrawlerRole.roleArn,
        targets: {
          s3Targets: [{
            path: `s3://${bucketName}/${tableName}/`
          }]
        },
        name: `${tablePrefix}${tableName}-${stage}`,
        tablePrefix: tablePrefix,
        schemaChangePolicy: {
          deleteBehavior: 'LOG'
        }
      });
    }

    const eventsCrawler = createCrawler(this, stage, ticketWarehouseBucket.bucketName, 'events', 'ticket_warehouse_');
    const ordersCrawler = createCrawler(this, stage, ticketWarehouseBucket.bucketName, 'orders', 'ticket_warehouse_');
    const ticketsCrawler = createCrawler(this, stage, ticketWarehouseBucket.bucketName, 'tickets', 'ticket_warehouse_');
    const ticketTypesCrawler = createCrawler(this, stage, ticketWarehouseBucket.bucketName, 'ticket_types', 'ticket_warehouse_');
    const checkinIDsCrawler = createCrawler(this, stage, ticketWarehouseBucket.bucketName, 'checkin_ids', 'ticket_warehouse_');
    const stripeChargesCrawler = createCrawler(this, stage, ticketWarehouseBucket.bucketName, 'stripe_charges', 'ticket_warehouse_');

    const utilSchemaInfoCrawler = createCrawler(this, stage, vaultBucket.bucketName, 'util_schema_info', 'vault_');
    const sevenroomsReservationsCrawler = createCrawler(this, stage, vaultBucket.bucketName, 'sevenrooms_reservations', 'vault_');
    const hotspotContactsCrawler = createCrawler(this, stage, vaultBucket.bucketName, 'hotspot_contacts', 'vault_');
    const dimTablesCrawler = createCrawler(this, stage, vaultBucket.bucketName, 'dim_tables', 'vault_');
    const tableReservationBridgeCrawler = createCrawler(this, stage, vaultBucket.bucketName, 'table_reservation_bridge', 'vault_');
    const dimMenuItemCrawler = createCrawler(this, stage, vaultBucket.bucketName, 'dim_menu_item', 'vault_');
    const dimProfitCenterCrawler = createCrawler(this, stage, vaultBucket.bucketName, 'dim_profit_center', 'vault_');
    const dimTerminalCrawler = createCrawler(this, stage, vaultBucket.bucketName, 'dim_terminal', 'vault_');
    const factTransactionCrawler = createCrawler(this, stage, vaultBucket.bucketName, 'fact_transaction', 'vault_');
    const dimTimeCrawler = createCrawler(this, stage, vaultBucket.bucketName, 'dim_time', 'vault_');
    const factTransactionItemCrawler = createCrawler(this, stage, vaultBucket.bucketName, 'fact_transaction_item', 'vault_');
    const personicxDetailsCrawler = createCrawler(this, stage, vaultBucket.bucketName, 'personicx_details', 'vault_');
    const emailValidationsCrawler = createCrawler(this, stage, vaultBucket.bucketName, 'email_validations', 'vault_');
    const fullContactBatchIdsCrawler = createCrawler(this, stage, vaultBucket.bucketName, 'full_contact_batch_ids', 'vault_');
    const dimLearnedFromCrawler = createCrawler(this, stage, vaultBucket.bucketName, 'dim_learned_from', 'vault_');
    const logKJBCrawler = createCrawler(this, stage, vaultBucket.bucketName, 'log_kjb', 'vault_');
    const utilJobsCrawler = createCrawler(this, stage, vaultBucket.bucketName, 'util_jobs', 'vault_');
    const logKTRCrawler = createCrawler(this, stage, vaultBucket.bucketName, 'log_ktr', 'vault_');
    const dimArtistsCrawler = createCrawler(this, stage, vaultBucket.bucketName, 'dim_artists', 'vault_');
    const postalCodesCrawler = createCrawler(this, stage, vaultBucket.bucketName, 'postal_codes', 'vault_');
    const dimEventArtistBridgeCrawler = createCrawler(this, stage, vaultBucket.bucketName, 'dim_event_artist_bridge', 'vault_');
    const trippleseatCommissionRatesCrawler = createCrawler(this, stage, vaultBucket.bucketName, 'trippleseat_commission_rates', 'vault_');
    const dimUniqueHumansCrawler = createCrawler(this, stage, vaultBucket.bucketName, 'dim_unique_humans', 'vault_');
    const hotpointActionsCrawler = createCrawler(this, stage, vaultBucket.bucketName, 'hotpoint_actions', 'vault_');
    const dimCustomerCodesCrawler = createCrawler(this, stage, vaultBucket.bucketName, 'dim_customer_codes', 'vault_');
    const dimCustomerCodeSetCustomerCodeBridgeCrawler = createCrawler(this, stage, vaultBucket.bucketName, 'dim_customer_code_set_customer_code_bridge', 'vault_');
    const resdiaryBookingReasonsCrawler = createCrawler(this, stage, vaultBucket.bucketName, 'resdiary_booking_reasons', 'vault_');
    const resdiaryPaymentsCrawler = createCrawler(this, stage, vaultBucket.bucketName, 'resdiary_payments', 'vault_');
    const hotpointContactsCrawler = createCrawler(this, stage, vaultBucket.bucketName, 'hotpoint_contacts', 'vault_');
    const daylightSavingsOffsetsCrawler = createCrawler(this, stage, vaultBucket.bucketName, 'daylight_savings_offsets', 'vault_');
    const resdiaryBookingsCrawler = createCrawler(this, stage, vaultBucket.bucketName, 'resdiary_bookings', 'vault_');
    const factTransactionTendersCrawler = createCrawler(this, stage, vaultBucket.bucketName, 'fact_transaction_tenders', 'vault_');
    const dimContactsCrawler = createCrawler(this, stage, vaultBucket.bucketName, 'dim_contacts', 'vault_');
    const geoIsoCountryCodesCrawler = createCrawler(this, stage, vaultBucket.bucketName, 'geo_iso_country_codes', 'vault_');
    const dimVenuesCrawler = createCrawler(this, stage, vaultBucket.bucketName, 'dim_venues', 'vault_');
    const dimCustomerCodeSetsCrawler = createCrawler(this, stage, vaultBucket.bucketName, 'dim_customer_code_sets', 'vault_');
    const dimDateCrawler = createCrawler(this, stage, vaultBucket.bucketName, 'dim_date', 'vault_');
    const nicknameSetsCrawler = createCrawler(this, stage, vaultBucket.bucketName, 'nickname_sets', 'vault_');
    const dimEmployeeCrawler = createCrawler(this, stage, vaultBucket.bucketName, 'dim_employee', 'vault_');
    const infoGenesisTenderLookupCrawler = createCrawler(this, stage, vaultBucket.bucketName, 'info_genesis_tender_lookup', 'vault_');
    const dimStaffEmployeeCrawler = createCrawler(this, stage, vaultBucket.bucketName, 'dim_staff_employee', 'vault_');
    const sevenroomsClientsCrawler = createCrawler(this, stage, vaultBucket.bucketName, 'sevenrooms_clients', 'vault_');
    const sevenroomsPosTicketsCrawler = createCrawler(this, stage, vaultBucket.bucketName, 'sevenrooms_pos_tickets', 'vault_');
    const sevenroomsPosTicketItemsCrawler = createCrawler(this, stage, vaultBucket.bucketName, 'sevenrooms_pos_ticket_items', 'vault_');
    const vdReservationPaymentsCrawler = createCrawler(this, stage, vaultBucket.bucketName, 'vd_reservation_payments', 'vault_');
    const resdiaryCustomersCrawler = createCrawler(this, stage, vaultBucket.bucketName, 'resdiary_customers', 'vault_');
    const trippleseatLeadsCrawler = createCrawler(this, stage, vaultBucket.bucketName, 'trippleseat_leads', 'vault_');
    const trippleseatContactsCrawler = createCrawler(this, stage, vaultBucket.bucketName, 'trippleseat_contacts', 'vault_');
    const trippleseatEventsCrawler = createCrawler(this, stage, vaultBucket.bucketName, 'trippleseat_events', 'vault_');
    const trippleseatEventTotalsCrawler = createCrawler(this, stage, vaultBucket.bucketName, 'trippleseat_event_totals', 'vault_');
    const trippleseatAccountsCrawler = createCrawler(this, stage, vaultBucket.bucketName, 'trippleseat_accounts', 'vault_');
    const trippleseatUsersCrawler = createCrawler(this, stage, vaultBucket.bucketName, 'trippleseat_users', 'vault_');
    const trippleseatEventCustomFieldsCrawler = createCrawler(this, stage, vaultBucket.bucketName, 'trippleseat_event_custom_fields', 'vault_');
    const resdiaryCustomerCodesCrawler = createCrawler(this, stage, vaultBucket.bucketName, 'resdiary_customer_codes', 'vault_');
    const trippleseatLocationsCrawler = createCrawler(this, stage, vaultBucket.bucketName, 'trippleseat_locations', 'vault_');
    const resdiaryBookingCodesCrawler = createCrawler(this, stage, vaultBucket.bucketName, 'resdiary_booking_codes', 'vault_');
    const resdiaryBookingPromotionsCrawler = createCrawler(this, stage, vaultBucket.bucketName, 'resdiary_booking_promotions', 'vault_');
    const resdiaryBookingTablesCrawler = createCrawler(this, stage, vaultBucket.bucketName, 'resdiary_booking_tables', 'vault_');
    const sfdcExistingIdsCrawler = createCrawler(this, stage, vaultBucket.bucketName, 'sfdc_existing_ids', 'vault_');
    const hotpointBoothMappingsCrawler = createCrawler(this, stage, vaultBucket.bucketName, 'hotpoint_booth_mappings', 'vault_');
    const vdItinerariesCrawler = createCrawler(this, stage, vaultBucket.bucketName, 'vd_itineraries', 'vault_');
    const wirelessSocialContactsCrawler = createCrawler(this, stage, vaultBucket.bucketName, 'wireless_social_contacts', 'vault_');
    const eventFormsCrawler = createCrawler(this, stage, vaultBucket.bucketName, 'event_forms', 'vault_');
    const openTableSyncGuestsCrawler = createCrawler(this, stage, vaultBucket.bucketName, 'open_table_sync_guests', 'vault_');
    const openTableSyncReservationsCrawler = createCrawler(this, stage, vaultBucket.bucketName, 'open_table_sync_reservations', 'vault_');
    const sfdcContactOptInsCrawler = createCrawler(this, stage, vaultBucket.bucketName, 'sfdc_contact_opt_ins', 'vault_');
    const derivedSingleVenueFormSubscribersCrawler = createCrawler(this, stage, vaultBucket.bucketName, 'derived_single_venue_form_subscribers', 'vault_');
    const formstackContactsCrawler = createCrawler(this, stage, vaultBucket.bucketName, 'formstack_contacts', 'vault_');
    const sfdcPreferencesBackupsRedoCrawler = createCrawler(this, stage, vaultBucket.bucketName, 'sfdc_preferences_backups_redo', 'vault_');
    const sfdcPreferencesBackupsCrawler = createCrawler(this, stage, vaultBucket.bucketName, 'sfdc_preferences_backups', 'vault_');
    const venueDriverPendingPersonalInfoPurgesCrawler = createCrawler(this, stage, vaultBucket.bucketName, 'venue_driver_pending_personal_info_purges', 'vault_');
    const venuedriverTicketRedemptionsCrawler = createCrawler(this, stage, vaultBucket.bucketName, 'venuedriver_ticket_redemptions', 'vault_');
    const vdPackageTicketsTicketsCrawler = createCrawler(this, stage, vaultBucket.bucketName, 'vd_package_tickets_tickets', 'vault_');
    const vdEventsPackageTicketsCrawler = createCrawler(this, stage, vaultBucket.bucketName, 'vd_events_package_tickets', 'vault_');
    const stripeRefundsCrawler = createCrawler(this, stage, vaultBucket.bucketName, 'stripe_refunds', 'vault_');
    const dimStripeChargesCrawler = createCrawler(this, stage, vaultBucket.bucketName, 'dim_stripe_charges', 'vault_');
    const venuedriverTicketKindsCrawler = createCrawler(this, stage, vaultBucket.bucketName, 'venuedriver_ticket_kinds', 'vault_');
    const dimEventCrawler = createCrawler(this, stage, vaultBucket.bucketName, 'dim_event', 'vault_');
    const manifestDeliveryControlsCrawler = createCrawler(this, stage, vaultBucket.bucketName, 'manifest_delivery_controls', 'vault_');
    const dimVdUsersCrawler = createCrawler(this, stage, vaultBucket.bucketName, 'dim_vd_users', 'vault_');
    const factActionsCrawler = createCrawler(this, stage, vaultBucket.bucketName, 'fact_actions', 'vault_');

    // Add dynamodb table for manifest_delivery_control
    const manifestDeliveryControlTable = new cdk.aws_dynamodb.Table(this, `ManifestDeliveryControlTable-${stage}`, {
      partitionKey: {
        name: 'event_key',
        type: cdk.aws_dynamodb.AttributeType.STRING
      },
      billingMode: cdk.aws_dynamodb.BillingMode.PAY_PER_REQUEST,
      tableName: `manifest_delivery_control-${stage}`
    });

    // Add function for manifest_delivery_control
    const manifestSendReportFunction = new Function(this, `ManifestSendReportFunction-${stage}`, {
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
      handler: 'manifest-report-handler.send_report_lambda_handler',
      environment: {
        'MANIFEST_DELIVERY_CONTROL_TABLE': manifestDeliveryControlTable.tableName
      },
      timeout: cdk.Duration.minutes(5),
      memorySize: 1024,
    });

    manifestSendReportFunction.addToRolePolicy(new iam.PolicyStatement({
      actions: [
        'athena:GetNamedQuery',
        'athena:ListNamedQueries',
        'athena:StartQueryExecution',
        'athena:GetQueryExecution',
        'athena:GetQueryResults',
        'ssm:GetParameter',
        's3:GetBucketLocation',
        's3:GetObject',
        's3:ListBucket',
        's3:ListBucketMultipartUploads',
        's3:ListMultipartUploadParts',
        's3:AbortMultipartUpload',
        's3:CreateBucket',
        's3:PutObject',
        'glue:GetDatabase',
        'glue:CreateDatabase',
        'glue:CreateTable',
        'glue:GetTable',
        'glue:GetPartitions',
        'glue:BatchCreatePartition',
        'glue:startCrawler',
        'ses:SendEmail',
        'ses:SendRawEmail'
      ],
      resources: ['*'],
    }));

    // Add function for manifest_delivery_control
    const manifestReportSchedulingFunction = new Function(this, `ManifestReportSchedulingFunction-${stage}`, {
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
      handler: 'manifest-report-handler.report_scheduling_lambda_handler',
      environment: {
        'MANIFEST_DELIVERY_CONTROL_TABLE': manifestDeliveryControlTable.tableName,
        'ENV': stage,
      },
      timeout: cdk.Duration.minutes(15),
      memorySize: 1024,
    });

    manifestReportSchedulingFunction.addToRolePolicy(new iam.PolicyStatement({
      actions: [
        'dynamodb:BatchGetItem',
        'athena:GetNamedQuery',
        'athena:ListNamedQueries',
        'athena:StartQueryExecution',
        'athena:GetQueryExecution',
        'athena:GetQueryResults',
        'ssm:GetParameter',
        's3:GetBucketLocation',
        's3:GetObject',
        's3:ListBucket',
        's3:ListBucketMultipartUploads',
        's3:ListMultipartUploadParts',
        's3:AbortMultipartUpload',
        's3:CreateBucket',
        's3:PutObject',
        'glue:GetDatabase',
        'glue:CreateDatabase',
        'glue:CreateTable',
        'glue:GetTable',
        'glue:GetPartitions',
        'glue:BatchCreatePartition',
        'glue:startCrawler',
        'ses:SendEmail',
        'ses:SendRawEmail'
      ],
      resources: ['*'],
    }));

    const ruleForManifestReportScheduling = new events.Rule(this, `RuleForManifestReportScheduling-${stage}`, {
      schedule: events.Schedule.rate(cdk.Duration.minutes(5))
    });
    ruleForManifestReportScheduling.addTarget(new targets.LambdaFunction(manifestReportSchedulingFunction));
    
    const dailyTicketSaleReportFunction = new Function(this, `DailyTicketSaleReportFunction-${stage}`, {
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
      handler: 'daily-ticket-sale-report-handler.lambda_handler',
      environment: {
        'ENV': stage,
      },
      timeout: cdk.Duration.minutes(5),
      memorySize: 1024,
    });

    dailyTicketSaleReportFunction.addToRolePolicy(new iam.PolicyStatement({
      actions: [
        'athena:GetNamedQuery',
        'athena:ListNamedQueries',
        'athena:StartQueryExecution',
        'athena:GetQueryExecution',
        'athena:GetQueryResults',
        'ssm:GetParameter',
        's3:GetBucketLocation',
        's3:GetObject',
        's3:ListBucket',
        's3:ListBucketMultipartUploads',
        's3:ListMultipartUploadParts',
        's3:AbortMultipartUpload',
        's3:CreateBucket',
        's3:PutObject',
        'glue:GetDatabase',
        'glue:CreateDatabase',
        'glue:CreateTable',
        'glue:GetTable',
        'glue:GetPartitions',
        'glue:BatchCreatePartition',
        'glue:startCrawler',
        'ses:SendEmail'
      ],
      resources: ['*'],
    }));

    const ruleForDailyTicketSaleReport = new events.Rule(this, `RuleForDailyTicketSaleReport-${stage}`, {
      schedule: events.Schedule.cron({ minute: '0', hour: '15' })
    });
    ruleForDailyTicketSaleReport.addTarget(new targets.LambdaFunction(dailyTicketSaleReportFunction));
  
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
