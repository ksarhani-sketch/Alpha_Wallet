import { Stack } from 'aws-cdk-lib';
import { UserPool, UserPoolClient, AccountRecovery } from 'aws-cdk-lib/aws-cognito';
import { Construct } from 'constructs';
import type { CoreStack } from './core-stack.js';

export class AuthStack extends Stack {
  readonly pool: UserPool;
  readonly client: UserPoolClient;

  constructor(scope: Construct, id: string, props: { env: any; core: CoreStack }) {
    super(scope, id, props);

    this.pool = new UserPool(this, 'UserPool', {
      selfSignUpEnabled: true,
      signInAliases: { email: true, phone: false, username: false },
      standardAttributes: { email: { required: true, mutable: true } },
      accountRecovery: AccountRecovery.EMAIL_ONLY,
    });

    this.client = new UserPoolClient(this, 'WebClient', {
      userPool: this.pool,
      generateSecret: false,
    });
  }
}
