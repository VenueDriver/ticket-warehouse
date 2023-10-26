#!/usr/bin/env node
import 'source-map-support/register';
import * as cdk from 'aws-cdk-lib';
import { Construct } from 'constructs';
import { TicketWarehousePipelineStack } from '../lib/pipeline/ticket-warehouse-pipeline';

import * as dotenv from 'dotenv';
import { SSM } from 'aws-sdk';

dotenv.config();

// utility function to get account IDs asynchronously
async function getAccountId(name: string, fallbackName: string): Promise<string> {
  if (process.env[name]) return process.env[name]!;

  const ssmClient = new SSM();
  try {
    const result = await ssmClient.getParameter({ Name: fallbackName.toLowerCase() }).promise();
    return result.Parameter?.Value || '';
  } catch (err) {
    console.error(`Error fetching SSM parameter ${fallbackName}:`, err);
    return '';
  }
}

async function main() {
  const app = new cdk.App();

  const deployFromAccount = await getAccountId('DEPLOYMENT_AWS_ACCOUNT_ID', 'DeploymentAWSAccountId');
  const productionAccount = await getAccountId('PRODUCTION_AWS_ACCOUNT_ID', 'ProductionAWSAccountId');
  const stagingAccount = await getAccountId('STAGING_AWS_ACCOUNT_ID', 'StagingAWSAccountId');
  const developmentAccount = await getAccountId('DEVELOPMENT_AWS_ACCOUNT_ID', 'DevelopmentAWSAccountId');

  class TicketWarehousePipelineStackWrapper extends cdk.Stack {
    constructor(scope: cdk.App, id: string, props?: cdk.StackProps) {
      super(scope, id, props);

      new TicketWarehousePipelineStack(this, 'ticket-warehouse-pipeline-staging', {
        env: { account: deployFromAccount, region: 'us-east-1' },
        Stage: 'staging',
        AccountToDeployTo: stagingAccount,
        DeploymentRegion: 'us-east-1'
      });

      new TicketWarehousePipelineStack(this, 'ticket-warehouse-pipeline-production', {
        env: { account: deployFromAccount, region: 'us-east-1' },
        Stage: 'production',
        AccountToDeployTo: productionAccount,
        DeploymentRegion: 'us-east-1'
      });

      new TicketWarehousePipelineStack(this, 'ticket-warehouse-pipeline-development', {
        env: { account: deployFromAccount, region: 'us-east-1' },
        Stage: 'development',
        AccountToDeployTo: developmentAccount,
        DeploymentRegion: 'us-east-1'
      });
    }
  }

  new TicketWarehousePipelineStackWrapper(app, 'TicketWarehousePipelineStackWrapper');
}

main().catch(err => {
  console.error('An error occurred:', err);
  process.exit(1);
});
