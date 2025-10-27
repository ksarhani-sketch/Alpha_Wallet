import { APIGatewayProxyHandlerV2 } from 'aws-lambda';
import { PutCommand, QueryCommand } from '@aws-sdk/lib-dynamodb';
import { ddb, env } from '../shared/dynamo.js';

export const handler: APIGatewayProxyHandlerV2 = async (event) => {
  const userId = event.requestContext.authorizer?.jwt?.claims?.sub || 'demo-user';
  if (event.requestContext.http.method === 'GET') {
    const yymm = event.queryStringParameters?.month || new Date().toISOString().slice(0, 7);
    const r = await ddb.send(
      new QueryCommand({
        TableName: env.budTable,
        KeyConditionExpression: 'userId = :u AND begins_with(periodCat, :p)',
        ExpressionAttributeValues: { ':u': userId, ':p': yymm },
      }),
    );
    return { statusCode: 200, body: JSON.stringify(r.Items ?? []) };
  }
  if (event.requestContext.http.method === 'POST') {
    const b = JSON.parse(event.body ?? '{}');
    const key = `${b.month}#${b.categoryId}`;
    const item = { userId, periodCat: key, amount_base: b.amount_base };
    await ddb.send(new PutCommand({ TableName: env.budTable, Item: item }));
    return { statusCode: 201, body: JSON.stringify(item) };
  }
  return { statusCode: 405, body: 'Method Not Allowed' };
};
