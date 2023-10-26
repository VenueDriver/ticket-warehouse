import * as cdk from 'aws-cdk-lib';
import { Construct } from 'constructs';
import { TicketWarehouseStage } from './ticket-warehouse-deployment-stage';
import { TicketWarehouseProps } from './ticket-warehouse-deployment-props';
import { StringParameter } from 'aws-cdk-lib/aws-ssm';
import * as dotenv from 'dotenv';

dotenv.config();

export class TicketWarehousePipelineStack extends cdk.Stack {
  constructor(scope: Construct, id: string, props: TicketWarehouseProps) {
    super(scope, id, props);

    const deploymentBranch = props.Stage;

    const githubConnectionArn = process.env.GITHUB_CONNECTION_ARN || StringParameter.valueFromLookup(this, 'ticket_warehouse_github_connection_arn');
    const githubRepository = process.env.GITHUB_REPOSITORY || StringParameter.valueFromLookup(this, 'ticket_warehouse_github_repository');

    // create pipeline
    const pipeline = new cdk.pipelines.CodePipeline(this, 'Pipeline', {
      pipelineName: `ticket-warehouse-pipeline-${props.Stage}`,
      crossAccountKeys: true,
      dockerEnabledForSynth: true,
      synth: new cdk.pipelines.ShellStep('Synth', {
        input: cdk.pipelines.CodePipelineSource.connection(cdk.Lazy.string({ produce: () => githubRepository }), deploymentBranch, {
          connectionArn: cdk.Lazy.string({ produce: () => githubConnectionArn }),
        }),
        commands: [
          'npm ci && npx audit-ci --high',
          `npx cdk synth ticket-warehouse-pipeline-${props.Stage}`
        ],
        primaryOutputDirectory: './ticket-warehouse/cdk.out',
      }),
    });

    pipeline.addStage(new TicketWarehouseStage(this, `${props.Stage}`, {
      env: { account: props.AccountToDeployTo, region: props.DeploymentRegion },
      Stage: props.Stage,
      AccountToDeployTo: props.AccountToDeployTo,
      DeploymentRegion: props.DeploymentRegion
    }));
  }
}
