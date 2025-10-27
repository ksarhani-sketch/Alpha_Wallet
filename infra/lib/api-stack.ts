import { Duration, Stack } from 'aws-cdk-lib';
import { RestApi, LambdaIntegration, Cors } from 'aws-cdk-lib/aws-apigateway';
import { NodejsFunction } from 'aws-cdk-lib/aws-lambda-nodejs';
import { Runtime } from 'aws-cdk-lib/aws-lambda';
import { Effect, PolicyStatement } from 'aws-cdk-lib/aws-iam';
import { Construct } from 'constructs';
import type { CoreStack } from './core-stack.js';
import type { AuthStack } from './auth-stack.js';

export class ApiStack extends Stack {
  readonly api: RestApi;

  constructor(scope: Construct, id: string, props: { env: any; core: CoreStack; auth: AuthStack }) {
    super(scope, id, props);

    this.api = new RestApi(this, 'Api', {
      defaultCorsPreflightOptions: {
        allowOrigins: Cors.ALL_ORIGINS,
        allowMethods: Cors.DEFAULT_METHODS,
      },
    });

    const tables = props.core.tables;

    const mkFn = (entry: string) =>
      new NodejsFunction(this, entry.replace(/[\/]/g, '-'), {
        entry: `../services/api/handlers/${entry}`,
        handler: 'handler',
        runtime: Runtime.NODEJS_20_X,
        memorySize: 1024,
        timeout: Duration.seconds(10),
        environment: {
          TABLE_TRANSACTIONS: tables['Transactions'].tableName,
          TABLE_ACCOUNTS: tables['Accounts'].tableName,
          TABLE_CATEGORIES: tables['Categories'].tableName,
          TABLE_BUDGETS: tables['Budgets'].tableName,
          BUCKET_ATTACHMENTS: props.core.attachments.bucketName,
        },
      });

    const grant = (fn: NodejsFunction) => {
      tables['Transactions'].grantReadWriteData(fn);
      tables['Accounts'].grantReadWriteData(fn);
      tables['Categories'].grantReadWriteData(fn);
      tables['Budgets'].grantReadWriteData(fn);
      props.core.attachments.grantReadWrite(fn);
      fn.addToRolePolicy(
        new PolicyStatement({
          effect: Effect.ALLOW,
          actions: ['s3:PutObject', 's3:GetObject'],
          resources: [`${props.core.attachments.bucketArn}/*`],
        }),
      );
    };

    const transactions = mkFn('transactions.ts');
    grant(transactions);
    const accounts = mkFn('accounts.ts');
    grant(accounts);
    const categories = mkFn('categories.ts');
    grant(categories);
    const budgets = mkFn('budgets.ts');
    grant(budgets);
    const presign = mkFn('presign.ts');
    grant(presign);

    const v1 = this.api.root.addResource('v1');
    v1.addResource('transactions').addMethod('GET', new LambdaIntegration(transactions));
    v1.addResource('transactions').addMethod('POST', new LambdaIntegration(transactions));
    v1.addResource('accounts').addMethod('GET', new LambdaIntegration(accounts));
    v1.addResource('accounts').addMethod('POST', new LambdaIntegration(accounts));
    v1.addResource('categories').addMethod('GET', new LambdaIntegration(categories));
    v1.addResource('categories').addMethod('POST', new LambdaIntegration(categories));
    v1.addResource('budgets').addMethod('GET', new LambdaIntegration(budgets));
    v1.addResource('budgets').addMethod('POST', new LambdaIntegration(budgets));
    v1.addResource('attachments').addResource('presign').addMethod('POST', new LambdaIntegration(presign));
  }
}
