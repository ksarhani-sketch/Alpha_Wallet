import { APIGatewayProxyHandlerV2 } from 'aws-lambda';
import { PutCommand, QueryCommand } from '@aws-sdk/lib-dynamodb';
import { ddb, env } from '../shared/dynamo.js';
import { randomUUID } from 'node:crypto';

export const handler: APIGatewayProxyHandlerV2 = async (event) => {
  const userId = event.requestContext.authorizer?.jwt?.claims?.sub || 'demo-user';
  if (event.requestContext.http.method === 'GET') {
    const r = await ddb.send(
      new QueryCommand({
        TableName: env.catTable,
        KeyConditionExpression: 'userId = :u',
        ExpressionAttributeValues: { ':u': userId },
      }),
    );
    return { statusCode: 200, body: JSON.stringify(r.Items ?? []) };
  }
  if (event.requestContext.http.method === 'POST') {
    const b = JSON.parse(event.body ?? '{}');
    const item = {
      userId,
      categoryId: randomUUID(),
      name: b.name,
      type: b.type ?? 'expense',
      color: b.color ?? '#36c',
      icon: b.icon ?? '📦',
    };
    await ddb.send(new PutCommand({ TableName: env.catTable, Item: item }));
    return { statusCode: 201, body: JSON.stringify(item) };
  }
  return { statusCode: 405, body: 'Method Not Allowed' };
};
