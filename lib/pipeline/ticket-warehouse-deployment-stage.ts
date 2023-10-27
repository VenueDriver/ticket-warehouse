import * as cdk from 'aws-cdk-lib';
import { Construct } from 'constructs';
// import * as sqs from 'aws-cdk-lib/aws-sqs';
import { TicketWarehouseStack } from '../ticket-warehouse-stack';
import { TicketWarehouseProps } from './ticket-warehouse-deployment-props';

export class TicketWarehouseStage extends cdk.Stage {
  constructor(scope: Construct, id: string, props: TicketWarehouseProps) {
    super(scope, id, props);

    const account = props.env?.account;
    const region = props.env?.region;
    const stage = props.Stage;
    const accountToDeployTo = props.AccountToDeployTo;
    const deploymentRegion = props.DeploymentRegion;

    const stack = new TicketWarehouseStack(this, `ticket-warehouse`, {
      env: { account: account, region: region },
      Stage: stage,
      AccountToDeployTo: accountToDeployTo,
      DeploymentRegion: deploymentRegion
    });
  }
}
