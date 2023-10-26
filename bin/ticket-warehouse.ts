#!/usr/bin/env node
import 'source-map-support/register';
import * as cdk from 'aws-cdk-lib';
import { Construct } from 'constructs';
import { TicketWarehousePipelineStack } from '../lib/pipeline/ticket-warehouse-pipeline';
import * as ssm from 'aws-cdk-lib/aws-ssm';

import * as dotenv from 'dotenv';
dotenv.config();

// utility function to get account IDs
function getAccountId(name: string, fallbackName: string, scope: Construct): string {
  return process.env[name] ? process.env[name]! : ssm.StringParameter.fromStringParameterAttributes(scope, `TicketWarehouse-${fallbackName}`, {
    parameterName: fallbackName.toLowerCase(),
    version: 1
  }).stringValue;
}

class TicketWarehousePipelineStackWrapper extends cdk.Stack {
  constructor(scope: cdk.App, id: string, props?: cdk.StackProps) {
    super(scope, id, props);

    const deployFromAccount = getAccountId('DEPLOYMENT_AWS_ACCOUNT_ID', 'DeploymentAWSAccountId', this);
    const productionAccount = getAccountId('PRODUCTION_AWS_ACCOUNT_ID', 'ProductionAWSAccountId', this);
    const stagingAccount = getAccountId('STAGING_AWS_ACCOUNT_ID', 'StagingAWSAccountId', this);
    const developmentAccount = getAccountId('DEVELOPMENT_AWS_ACCOUNT_ID', 'DevelopmentAWSAccountId', this);

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

const app = new cdk.App();
new TicketWarehousePipelineStackWrapper(app, 'TicketWarehousePipelineStackWrapper');
