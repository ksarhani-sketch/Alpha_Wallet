import { Duration, Stack } from 'aws-cdk-lib';
import { Rule, Schedule } from 'aws-cdk-lib/aws-events';
import { LambdaFunction } from 'aws-cdk-lib/aws-events-targets';
import { NodejsFunction } from 'aws-cdk-lib/aws-lambda-nodejs';
import { Runtime } from 'aws-cdk-lib/aws-lambda';
import type { CoreStack } from './core-stack.js';
import { Construct } from 'constructs';

export class JobsStack extends Stack {
  constructor(scope: Construct, id: string, props: { env: any; core: CoreStack; api: any }) {
    super(scope, id, props);

    const updateFx = new NodejsFunction(this, 'UpdateFx', {
      entry: '../services/jobs/updateFx.ts',
      handler: 'handler',
      runtime: Runtime.NODEJS_20_X,
      timeout: Duration.seconds(30),
      memorySize: 1024,
      environment: { TABLE_TRANSACTIONS: props.core.tables['Transactions'].tableName },
    });

    new Rule(this, 'UpdateFxDaily', {
      schedule: Schedule.cron({ minute: '0', hour: '1' }),
      targets: [new LambdaFunction(updateFx)],
    });
  }
}
