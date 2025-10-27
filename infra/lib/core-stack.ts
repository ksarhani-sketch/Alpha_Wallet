import { Duration, RemovalPolicy, Stack } from 'aws-cdk-lib';
import { AttributeType, BillingMode, Table } from 'aws-cdk-lib/aws-dynamodb';
import { Bucket, BlockPublicAccess } from 'aws-cdk-lib/aws-s3';
import { Key } from 'aws-cdk-lib/aws-kms';
import { Construct } from 'constructs';

export class CoreStack extends Stack {
  readonly k: Key;
  readonly attachments: Bucket;
  readonly exportsBucket: Bucket;
  readonly tables: Record<string, Table> = {};

  constructor(scope: Construct, id: string, props?: any) {
    super(scope, id, props);

    this.k = new Key(this, 'KmsKey', { enableKeyRotation: true });

    this.attachments = new Bucket(this, 'Attachments', {
      blockPublicAccess: BlockPublicAccess.BLOCK_ALL,
      encryptionKey: this.k,
      enforceSSL: true,
      versioned: true,
      lifecycleRules: [{ expiration: Duration.days(365 * 3) }],
    });

    this.exportsBucket = new Bucket(this, 'Exports', {
      blockPublicAccess: BlockPublicAccess.BLOCK_ALL,
      encryptionKey: this.k,
      enforceSSL: true,
      versioned: true,
      lifecycleRules: [{ expiration: Duration.days(365 * 3) }],
    });

    const commonTableProps = {
      billingMode: BillingMode.PAY_PER_REQUEST,
      removalPolicy: RemovalPolicy.DESTROY,
      encryptionKey: this.k,
      pointInTimeRecovery: true,
    } as const;

    this.tables['Users'] = new Table(this, 'Users', {
      ...commonTableProps,
      partitionKey: { name: 'userId', type: AttributeType.STRING },
    });

    this.tables['Accounts'] = new Table(this, 'Accounts', {
      ...commonTableProps,
      partitionKey: { name: 'userId', type: AttributeType.STRING },
      sortKey: { name: 'accountId', type: AttributeType.STRING },
    });

    this.tables['Categories'] = new Table(this, 'Categories', {
      ...commonTableProps,
      partitionKey: { name: 'userId', type: AttributeType.STRING },
      sortKey: { name: 'categoryId', type: AttributeType.STRING },
    });

    this.tables['Transactions'] = new Table(this, 'Transactions', {
      ...commonTableProps,
      partitionKey: { name: 'userId', type: AttributeType.STRING },
      sortKey: { name: 'sk', type: AttributeType.STRING },
    });

    this.tables['Budgets'] = new Table(this, 'Budgets', {
      ...commonTableProps,
      partitionKey: { name: 'userId', type: AttributeType.STRING },
      sortKey: { name: 'periodCat', type: AttributeType.STRING },
    });

    this.tables['Recurring'] = new Table(this, 'Recurring', {
      ...commonTableProps,
      partitionKey: { name: 'userId', type: AttributeType.STRING },
      sortKey: { name: 'ruleId', type: AttributeType.STRING },
    });
  }
}
