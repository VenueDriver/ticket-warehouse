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
  parameterName: `TicketWarehouse-DeploymentAWSAccountId`,
  version: 1
}).stringValue;

const productionAccount = process.env.PRODUCTION_AWS_ACCOUNT_ID ? process.env.PRODUCTION_AWS_ACCOUNT_ID : ssm.StringParameter.fromStringParameterAttributes(app, `TicketWarehouse-ProductionAWSAccountId`, {
  parameterName: `TicketWarehouse-ProductionAWSAccountId`,
  version: 1
}).stringValue;

const stagingAccount = process.env.STAGING_AWS_ACCOUNT_ID ? process.env.STAGING_AWS_ACCOUNT_ID : ssm.StringParameter.fromStringParameterAttributes(app, `TicketWarehouse-StagingAWSAccountId`, {
  parameterName: `TicketWarehouse-StagingAWSAccountId`,
  version: 1
}).stringValue;

new TicketWarehousePipelineStack(app, 'absences-to-hotschedules-pipeline-staging', {
  // where the pipeline will run
  env: { account: deployFromAccount, region: 'us-east-1' },
  Stage: 'staging',
  // where the cdk app will be deployed
  AccountToDeployTo: stagingAccount,
  DeploymentRegion: 'us-east-1'
});

new TicketWarehousePipelineStack(app, 'absences-to-hotschedules-pipeline-production', {
  // where the pipeline will run
  env: { account: deployFromAccount, region: 'us-east-1' },
  Stage: 'production',
  // where the cdk app will be deployed
  AccountToDeployTo: productionAccount,
  DeploymentRegion: 'us-east-1'
});