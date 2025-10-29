import { Duration, Stack } from 'aws-cdk-lib';
import {
  RestApi,
  LambdaIntegration,
  Cors,
  CognitoUserPoolsAuthorizer,
  AuthorizationType,
  AccessLogFormat,
  MethodLoggingLevel,
  LogGroupLogDestination,
} from 'aws-cdk-lib/aws-apigateway';
import { NodejsFunction } from 'aws-cdk-lib/aws-lambda-nodejs';
import { Runtime } from 'aws-cdk-lib/aws-lambda';
import { Effect, PolicyStatement } from 'aws-cdk-lib/aws-iam';
import { Construct } from 'constructs';
import { LogGroup, RetentionDays } from 'aws-cdk-lib/aws-logs';
import type { CoreStack } from './core-stack.js';
import type { AuthStack } from './auth-stack.js';

export class ApiStack extends Stack {
  readonly api: RestApi;

  constructor(scope: Construct, id: string, props: { env: any; core: CoreStack; auth: AuthStack }) {
    super(scope, id, props);

    const accessLogs = new LogGroup(this, 'ApiAccessLogs', {
      retention: RetentionDays.ONE_MONTH,
    });

    this.api = new RestApi(this, 'Api', {
      defaultCorsPreflightOptions: {
        allowOrigins: Cors.ALL_ORIGINS,
        allowMethods: Cors.DEFAULT_METHODS,
      },
      deployOptions: {
        loggingLevel: MethodLoggingLevel.INFO,
        metricsEnabled: true,
        dataTraceEnabled: false,
        accessLogDestination: new LogGroupLogDestination(accessLogs),
        accessLogFormat: AccessLogFormat.jsonWithStandardFields({
          caller: true,
          user: true,
          requestTime: true,
          protocol: true,
          httpMethod: true,
          ip: true,
          resourcePath: true,
          responseLength: true,
          status: true,
        }),
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

    const authorizer = new CognitoUserPoolsAuthorizer(this, 'ApiAuthorizer', {
      cognitoUserPools: [props.auth.pool],
      identitySource: 'method.request.header.Authorization',
    });

    const methodOptions = {
      authorizer,
      authorizationType: AuthorizationType.COGNITO,
    } as const;

    const v1 = this.api.root.addResource('v1');

    const transactionsResource = v1.addResource('transactions');
    const transactionIntegration = new LambdaIntegration(transactions);
    transactionsResource.addMethod('GET', transactionIntegration, methodOptions);
    transactionsResource.addMethod('POST', transactionIntegration, methodOptions);
    const transactionItem = transactionsResource.addResource('{txnId}');
    transactionItem.addMethod('GET', transactionIntegration, methodOptions);
    transactionItem.addMethod('PUT', transactionIntegration, methodOptions);
    transactionItem.addMethod('DELETE', transactionIntegration, methodOptions);

    const accountsResource = v1.addResource('accounts');
    const accountIntegration = new LambdaIntegration(accounts);
    accountsResource.addMethod('GET', accountIntegration, methodOptions);
    accountsResource.addMethod('POST', accountIntegration, methodOptions);
    const accountItem = accountsResource.addResource('{accountId}');
    accountItem.addMethod('GET', accountIntegration, methodOptions);
    accountItem.addMethod('PUT', accountIntegration, methodOptions);
    accountItem.addMethod('DELETE', accountIntegration, methodOptions);

    const categoriesResource = v1.addResource('categories');
    const categoryIntegration = new LambdaIntegration(categories);
    categoriesResource.addMethod('GET', categoryIntegration, methodOptions);
    categoriesResource.addMethod('POST', categoryIntegration, methodOptions);
    const categoryItem = categoriesResource.addResource('{categoryId}');
    categoryItem.addMethod('GET', categoryIntegration, methodOptions);
    categoryItem.addMethod('PUT', categoryIntegration, methodOptions);
    categoryItem.addMethod('DELETE', categoryIntegration, methodOptions);

    const budgetsResource = v1.addResource('budgets');
    const budgetIntegration = new LambdaIntegration(budgets);
    budgetsResource.addMethod('GET', budgetIntegration, methodOptions);
    budgetsResource.addMethod('POST', budgetIntegration, methodOptions);
    const budgetMonth = budgetsResource.addResource('{month}');
    budgetMonth.addMethod('GET', budgetIntegration, methodOptions);
    const budgetEntry = budgetMonth.addResource('{categoryId}');
    budgetEntry.addMethod('GET', budgetIntegration, methodOptions);
    budgetEntry.addMethod('PUT', budgetIntegration, methodOptions);
    budgetEntry.addMethod('DELETE', budgetIntegration, methodOptions);

    const attachments = v1.addResource('attachments');
    attachments
      .addResource('presign')
      .addMethod('POST', new LambdaIntegration(presign), methodOptions);
  }
}
