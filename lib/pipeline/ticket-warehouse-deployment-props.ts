import { StackProps, StageProps } from 'aws-cdk-lib';

export interface TicketWarehouseProps extends StackProps, StageProps{
  readonly Stage : string;
  readonly AccountToDeployTo : string;
  readonly DeploymentRegion : string;
}