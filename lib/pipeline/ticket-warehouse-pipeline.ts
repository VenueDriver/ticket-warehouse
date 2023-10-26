import * as cdk from 'aws-cdk-lib';
import { Construct } from 'constructs';
import { TicketWarehouseStage } from './ticket-warehouse-deployment-stage';
import { TicketWarehouseProps } from './ticket-warehouse-deployment-props';
import * as ssm from 'aws-cdk-lib/aws-ssm';

import * as dotenv from 'dotenv';
dotenv.config();

export class TicketWarehousePipelineStack extends cdk.Stack {
  constructor(scope: Construct, id: string, props: TicketWarehouseProps) {
    super(scope, id, props);

    // constant for pipeline branch
    const deploymentBranch = props.Stage;

    // if process.env.GITHUB_CONNECTION_ARN exists, use it, otherwise get it from AWS Systems Manager Parameter Store
    const githubConnectionArn = process.env.GITHUB_CONNECTION_ARN ? process.env.GITHUB_CONNECTION_ARN : ssm.StringParameter.valueForStringParameter(this, 'ticket_warehouse_github_connection_arn');

    const githubRepository = process.env.GITHUB_REPOSITORY ? process.env.GITHUB_REPOSITORY : ssm.StringParameter.valueForStringParameter(this, 'ticket_warehouse_github_repository');

    // create pipeline
    const pipeline = new cdk.pipelines.CodePipeline(this, 'Pipeline', {
      // The pipeline name
      pipelineName: `ticket-warehouse-pipeline-${props.Stage}`,
      crossAccountKeys: true,
      dockerEnabledForSynth: true,
        // How it will be built and synthesized
        synth: new cdk.pipelines.ShellStep('Synth', {
          // Where the source can be found
          input: cdk.pipelines.CodePipelineSource.connection(githubRepository, deploymentBranch, {
            connectionArn: githubConnectionArn, // Created using the AWS console
          }),

          // Install dependencies, build and run cdk synth
          commands: [
            'npm ci && npx audit-ci --high',
            `npx cdk synth ticket-warehouse-pipeline-${props.Stage}`
          ],
          primaryOutputDirectory: './cdk.out',
        }),
    });

    /**
     * Stages
     */

    pipeline.addStage(new TicketWarehouseStage(this, `${props.Stage}`, {
      env: { account: props.AccountToDeployTo, region: props.DeploymentRegion },
      Stage: props.Stage,
      AccountToDeployTo: props.AccountToDeployTo,
      DeploymentRegion: props.DeploymentRegion
    }));

  }
}
