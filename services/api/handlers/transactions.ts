import { APIGatewayProxyHandlerV2 } from 'aws-lambda';
import { PutCommand, QueryCommand } from '@aws-sdk/lib-dynamodb';
import { ddb, env } from '../shared/dynamo.js';
import { randomUUID } from 'node:crypto';

export const handler: APIGatewayProxyHandlerV2 = async (event) => {
  const userId = event.requestContext.authorizer?.jwt?.claims?.sub || 'demo-user';
  const now = new Date().toISOString();

  if (event.requestContext.http.method === 'GET') {
    const from = event.queryStringParameters?.from || new Date(new Date().getFullYear(), new Date().getMonth(), 1).toISOString();
    const to = event.queryStringParameters?.to || new Date().toISOString();
    const r = await ddb.send(
      new QueryCommand({
        TableName: env.txTable,
        KeyConditionExpression: 'userId = :u AND sk BETWEEN :from AND :to',
        ExpressionAttributeValues: { ':u': userId, ':from': `DT#${from}`, ':to': `DT#${to}` },
      }),
    );
    return { statusCode: 200, body: JSON.stringify(r.Items ?? []) };
  }

  if (event.requestContext.http.method === 'POST') {
    const b = JSON.parse(event.body ?? '{}');
    const id = randomUUID();
    const occurredAt = b.occurredAt ?? now;
    const item = {
      userId,
      sk: `DT#${occurredAt}#TX#${id}`,
      txnId: id,
      type: b.type,
      accountId: b.accountId,
      categoryId: b.categoryId,
      amount: b.amount,
      currency: b.currency ?? 'OMR',
      fx_rate_to_base: b.fx_rate_to_base ?? 1,
      amount_base: (b.amount ?? 0) * (b.fx_rate_to_base ?? 1),
      note: b.note ?? null,
      tags: b.tags ?? [],
      occurredAt,
      createdAt: now,
    };
    await ddb.send(new PutCommand({ TableName: env.txTable, Item: item }));
    return { statusCode: 201, body: JSON.stringify(item) };
  }

  return { statusCode: 405, body: 'Method Not Allowed' };
};
