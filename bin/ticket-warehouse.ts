#!/usr/bin/env node
import 'source-map-support/register';
import * as cdk from 'aws-cdk-lib';
import { TicketWarehousePipelineStack } from '../lib/pipeline/ticket-warehouse-pipeline';
import * as ssm from 'aws-cdk-lib/aws-ssm';

import * as dotenv from 'dotenv';
dotenv.config();

const app = new cdk.App();

// accounts
const deployFromAccount = process.env.DEPLOYMENT_AWS_ACCOUNT_ID ? process.env.DEPLOYMENT_AWS_ACCOUNT_ID : ssm.StringParameter.fromStringParameterAttributes(app, `TicketWarehouse-DeploymentAWSAccountId`, {
  parameterName: 'deployment_aws_account_id',
  version: 1
}).stringValue;

const productionAccount = process.env.PRODUCTION_AWS_ACCOUNT_ID ? process.env.PRODUCTION_AWS_ACCOUNT_ID : ssm.StringParameter.fromStringParameterAttributes(app, `TicketWarehouse-ProductionAWSAccountId`, {
  parameterName: 'production_aws_account_id',
  version: 1
}).stringValue;

const stagingAccount = process.env.STAGING_AWS_ACCOUNT_ID ? process.env.STAGING_AWS_ACCOUNT_ID : ssm.StringParameter.fromStringParameterAttributes(app, `TicketWarehouse-StagingAWSAccountId`, {
  parameterName: 'staging_aws_account_id',
  version: 1
}).stringValue;

const developmentAccount = process.env.DEVELOPMENT_AWS_ACCOUNT_ID ? process.env.DEVELOPMENT_AWS_ACCOUNT_ID : ssm.StringParameter.fromStringParameterAttributes(app, `TicketWarehouse-DevelopmentAWSAccountId`, {
  parameterName: 'development_aws_account_id',
  version: 1
}).stringValue;

new TicketWarehousePipelineStack(app, 'ticket-warehouse-pipeline-staging', {
  // where the pipeline will run
  env: { account: deployFromAccount, region: 'us-east-1' },
  Stage: 'staging',
  // where the cdk app will be deployed
  AccountToDeployTo: stagingAccount,
  DeploymentRegion: 'us-east-1'
});

new TicketWarehousePipelineStack(app, 'ticket-warehouse-pipeline-production', {
  // where the pipeline will run
  env: { account: deployFromAccount, region: 'us-east-1' },
  Stage: 'production',
  // where the cdk app will be deployed
  AccountToDeployTo: productionAccount,
  DeploymentRegion: 'us-east-1'
});

new TicketWarehousePipelineStack(app, 'ticket-warehouse-pipeline-development', {
  // where the pipeline will run
  env: { account: deployFromAccount, region: 'us-east-1' },
  Stage: 'development',
  // where the cdk app will be deployed
  AccountToDeployTo: developmentAccount,
  DeploymentRegion: 'us-east-1'
});