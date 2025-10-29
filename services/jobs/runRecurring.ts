import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import { DynamoDBDocumentClient, ScanCommand, TransactWriteCommand } from '@aws-sdk/lib-dynamodb';
import { Handler } from 'aws-lambda';
import { randomUUID } from 'node:crypto';

const client = DynamoDBDocumentClient.from(new DynamoDBClient({}));

type RecurrenceFrequency = 'daily' | 'weekly' | 'monthly' | 'quarterly' | 'yearly';

type RecurringTemplate = {
  accountId: string;
  categoryId: string;
  type: 'expense' | 'income';
  amount: number;
  currency: string;
  note?: string | null;
  tags?: string[];
};

type RecurringRule = {
  userId: string;
  ruleId: string;
  frequency: RecurrenceFrequency;
  nextRun: string;
  template: RecurringTemplate;
  baseFx?: number;
};

const computeNextRun = (frequency: RecurrenceFrequency, reference: Date): Date => {
  const next = new Date(reference.getTime());
  switch (frequency) {
    case 'daily':
      next.setUTCDate(next.getUTCDate() + 1);
      break;
    case 'weekly':
      next.setUTCDate(next.getUTCDate() + 7);
      break;
    case 'monthly':
      next.setUTCMonth(next.getUTCMonth() + 1);
      break;
    case 'quarterly':
      next.setUTCMonth(next.getUTCMonth() + 3);
      break;
    case 'yearly':
      next.setUTCFullYear(next.getUTCFullYear() + 1);
      break;
    default:
      next.setUTCDate(next.getUTCDate() + 1);
  }
  return next;
};

const typeToDelta = (type: string, amount: number) => (type === 'expense' ? -amount : amount);

export const handler: Handler = async () => {
  const recurringTable = process.env.TABLE_RECURRING;
  const transactionsTable = process.env.TABLE_TRANSACTIONS;
  const accountsTable = process.env.TABLE_ACCOUNTS;

  if (!recurringTable || !transactionsTable || !accountsTable) {
    console.warn('Recurring job missing required environment configuration.');
    return;
  }

  const now = new Date();
  let exclusiveStartKey: Record<string, unknown> | undefined;
  do {
    const scan = await client.send(
      new ScanCommand({
        TableName: recurringTable,
        ExclusiveStartKey: exclusiveStartKey,
      }),
    );
    exclusiveStartKey = scan.LastEvaluatedKey as Record<string, unknown> | undefined;

    for (const item of scan.Items ?? []) {
      const rule = item as unknown as RecurringRule;
      if (!rule.nextRun || !rule.template) continue;
      const nextRunDate = new Date(rule.nextRun);
      if (Number.isNaN(nextRunDate.getTime())) continue;
      if (nextRunDate.getTime() > now.getTime()) continue;

      const template = rule.template;
      if (!template.accountId || !template.categoryId) continue;
      if (template.amount <= 0) continue;
      if (!['expense', 'income'].includes(template.type)) continue;

      const txnId = randomUUID();
      const occurredAt = now.toISOString();
      const sk = `DT#${occurredAt}#TX#${txnId}`;
      const fx = typeof rule.baseFx === 'number' && rule.baseFx > 0 ? rule.baseFx : 1;
      const amountBase = template.amount * fx;

      const transactItems: Parameters<TransactWriteCommand['constructor']>[0]['TransactItems'] = [
        {
          Put: {
            TableName: transactionsTable,
            Item: {
              userId: rule.userId,
              sk,
              txnId,
              accountId: template.accountId,
              categoryId: template.categoryId,
              type: template.type,
              amount: template.amount,
              currency: template.currency,
              fx_rate_to_base: fx,
              amount_base: amountBase,
              note: template.note ?? null,
              tags: template.tags ?? [],
              occurredAt,
              createdAt: occurredAt,
              updatedAt: occurredAt,
            },
            ConditionExpression: 'attribute_not_exists(sk)',
          },
        },
        {
          Update: {
            TableName: accountsTable,
            Key: { userId: rule.userId, accountId: template.accountId },
            UpdateExpression: 'SET currentBalance = if_not_exists(currentBalance, :zero) + :delta, updatedAt = :now',
            ExpressionAttributeValues: {
              ':zero': 0,
              ':delta': typeToDelta(template.type, template.amount),
              ':now': occurredAt,
            },
            ConditionExpression: 'attribute_exists(accountId)',
          },
        },
        {
          Update: {
            TableName: recurringTable,
            Key: { userId: rule.userId, ruleId: rule.ruleId },
            UpdateExpression: 'SET nextRun = :next, updatedAt = :now',
            ExpressionAttributeValues: {
              ':next': computeNextRun(rule.frequency, nextRunDate).toISOString(),
              ':now': occurredAt,
            },
            ConditionExpression: 'attribute_exists(ruleId)',
          },
        },
      ];

      try {
        await client.send(new TransactWriteCommand({ TransactItems: transactItems }));
      } catch (error) {
        console.error('Failed to materialise recurring transaction', {
          ruleId: rule.ruleId,
          userId: rule.userId,
          error,
        });
      }
    }
  } while (exclusiveStartKey);
};
