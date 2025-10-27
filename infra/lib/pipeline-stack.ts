import { SecretValue, Stack } from 'aws-cdk-lib';
import { Construct } from 'constructs';
import { Artifact, Pipeline } from 'aws-cdk-lib/aws-codepipeline';
import { GitHubSourceAction, CodeBuildAction, ManualApprovalAction } from 'aws-cdk-lib/aws-codepipeline-actions';
import { BuildSpec, LinuxBuildImage, PipelineProject } from 'aws-cdk-lib/aws-codebuild';

export class PipelineStack extends Stack {
  constructor(
    scope: Construct,
    id: string,
    props: { env: any; repo: { owner: string; name: string; oauthSecretArn: string }; branch: string; tags?: Record<string, string> },
  ) {
    super(scope, id, props);

    const sourceOutput = new Artifact('Source');

    const pipeline = new Pipeline(this, 'Pipeline', {
      restartExecutionOnUpdate: true,
    });

    pipeline.addStage({
      stageName: 'Source',
      actions: [
        new GitHubSourceAction({
          actionName: 'GitHub',
          owner: props.repo.owner,
          repo: props.repo.name,
          branch: props.branch,
          oauthToken: SecretValue.secretsManager(props.repo.oauthSecretArn),
          output: sourceOutput,
        }),
      ],
    });

    const infraProject = new PipelineProject(this, 'InfraBuild', {
      environment: { buildImage: LinuxBuildImage.STANDARD_7_0 },
      buildSpec: BuildSpec.fromSourceFilename('infra/buildspec-infra.yml'),
    });

    const svcProject = new PipelineProject(this, 'ServicesBuild', {
      environment: { buildImage: LinuxBuildImage.STANDARD_7_0 },
      buildSpec: BuildSpec.fromSourceFilename('services/buildspec-services.yml'),
    });

    const infraOut = new Artifact('InfraOut');
    const svcOut = new Artifact('SvcOut');

    pipeline.addStage({
      stageName: 'Build',
      actions: [
        new CodeBuildAction({ actionName: 'Infra', project: infraProject, input: sourceOutput, outputs: [infraOut] }),
        new CodeBuildAction({ actionName: 'Services', project: svcProject, input: sourceOutput, outputs: [svcOut] }),
      ],
    });

    pipeline.addStage({ stageName: 'Approve', actions: [new ManualApprovalAction({ actionName: 'PromoteToProd' })] });
  }
}
