import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import { DynamoDBDocumentClient, UpdateCommand } from '@aws-sdk/lib-dynamodb';
import { Handler } from 'aws-lambda';

const client = DynamoDBDocumentClient.from(new DynamoDBClient({}));

export const handler: Handler = async () => {
  const table = process.env.TABLE_TRANSACTIONS;
  if (!table) {
    console.warn('Missing TABLE_TRANSACTIONS environment variable.');
    return;
  }

  const rate = 0.39; // placeholder conversion rate
  await client.send(
    new UpdateCommand({
      TableName: table,
      Key: { userId: 'demo-user', sk: 'DT#2024-01-01#TX#seed' },
      UpdateExpression: 'SET fx_rate_to_base = :r',
      ExpressionAttributeValues: { ':r': rate },
    }),
  );
};
