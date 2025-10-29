import { APIGatewayProxyHandlerV2 } from 'aws-lambda';
import {
  DeleteCommand,
  PutCommand,
  QueryCommand,
  UpdateCommand,
} from '@aws-sdk/lib-dynamodb';
import { ddb, env } from '../shared/dynamo.js';
import { randomUUID } from 'node:crypto';
import { HttpError, jsonResponse, parseJson, requireUserId, validate } from '../shared/http.js';

const allowedAccountTypes = new Set(['cash', 'bank', 'card', 'crypto']);

const normaliseType = (type: unknown): string => {
  validate(typeof type === 'string', 400, 'Account type is required');
  const value = type.toLowerCase();
  validate(allowedAccountTypes.has(value), 400, `Account type must be one of: ${[...allowedAccountTypes].join(', ')}`);
  return value;
};

const normaliseCurrency = (currency: unknown): string => {
  validate(typeof currency === 'string' && currency.trim().length === 3, 400, 'Currency must be a 3-letter ISO code');
  return currency.toUpperCase();
};

interface AccountPayload {
  name: string;
  type: string;
  currency: string;
  openingBalance?: number;
  archived?: boolean;
}

export const handler: APIGatewayProxyHandlerV2 = async (event) => {
  try {
    const method = event.requestContext.http.method;
    const userId = requireUserId(event);
    const accountId = event.pathParameters?.accountId;

    if (method === 'GET') {
      if (accountId) {
        const result = await ddb.send(
          new QueryCommand({
            TableName: env.accTable,
            KeyConditionExpression: 'userId = :u AND accountId = :a',
            ExpressionAttributeValues: {
              ':u': userId,
              ':a': accountId,
            },
            Limit: 1,
          }),
        );
        const account = result.Items?.[0];
        if (!account) {
          throw new HttpError(404, 'Account not found');
        }
        return jsonResponse(200, account);
      }

      const r = await ddb.send(
        new QueryCommand({
          TableName: env.accTable,
          KeyConditionExpression: 'userId = :u',
          ExpressionAttributeValues: { ':u': userId },
        }),
      );
      return jsonResponse(200, r.Items ?? []);
    }

    if (method === 'POST') {
      const body = parseJson<AccountPayload>(event.body);
      validate(typeof body.name === 'string' && body.name.trim().length > 1, 400, 'Account name is required');
      const type = normaliseType(body.type);
      const currency = normaliseCurrency(body.currency);
      const openingBalance = body.openingBalance === undefined ? 0 : Number(body.openingBalance);
      validate(Number.isFinite(openingBalance), 400, 'Opening balance must be numeric');

      const now = new Date().toISOString();
      const item = {
        userId,
        accountId: randomUUID(),
        name: body.name.trim(),
        type,
        currency,
        openingBalance,
        currentBalance: openingBalance,
        archived: Boolean(body.archived),
        createdAt: now,
        updatedAt: now,
      };
      await ddb.send(new PutCommand({ TableName: env.accTable, Item: item }));
      return jsonResponse(201, item);
    }

    if (method === 'PUT') {
      validate(Boolean(accountId), 400, 'Account identifier is required');
      const body = parseJson<Partial<AccountPayload>>(event.body);
      const updates: string[] = [];
      const values: Record<string, unknown> = { ':now': new Date().toISOString() };

      if (typeof body.name === 'string') {
        validate(body.name.trim().length > 1, 400, 'Account name cannot be empty');
        updates.push('name = :name');
        values[':name'] = body.name.trim();
      }

      if (body.type !== undefined) {
        updates.push('type = :type');
        values[':type'] = normaliseType(body.type);
      }

      if (body.currency !== undefined) {
        updates.push('currency = :currency');
        values[':currency'] = normaliseCurrency(body.currency);
      }

      if (body.archived !== undefined) {
        updates.push('archived = :archived');
        values[':archived'] = Boolean(body.archived);
      }

      if (body.openingBalance !== undefined) {
        const openingBalance = Number(body.openingBalance);
        validate(Number.isFinite(openingBalance), 400, 'Opening balance must be numeric');
        updates.push('openingBalance = :opening');
        values[':opening'] = openingBalance;
      }

      validate(updates.length > 0, 400, 'No updatable fields provided');
      updates.push('updatedAt = :now');

      const result = await ddb.send(
        new UpdateCommand({
          TableName: env.accTable,
          Key: { userId, accountId },
          ConditionExpression: 'attribute_exists(accountId)',
          UpdateExpression: `SET ${updates.join(', ')}`,
          ExpressionAttributeValues: values,
          ReturnValues: 'ALL_NEW',
        }),
      );
      return jsonResponse(200, result.Attributes);
    }

    if (method === 'DELETE') {
      validate(Boolean(accountId), 400, 'Account identifier is required');
      const transactions = await ddb.send(
        new QueryCommand({
          TableName: env.txTable,
          KeyConditionExpression: 'userId = :u',
          ExpressionAttributeValues: {
            ':u': userId,
            ':account': accountId,
          },
          FilterExpression: 'accountId = :account',
          Limit: 1,
        }),
      );

      validate((transactions.Items?.length ?? 0) === 0, 409, 'Account cannot be deleted while transactions exist');

      await ddb.send(
        new DeleteCommand({
          TableName: env.accTable,
          Key: { userId, accountId },
          ConditionExpression: 'attribute_exists(accountId)',
        }),
      );
      return jsonResponse(204, null);
    }

    return jsonResponse(405, { message: 'Method Not Allowed' });
  } catch (error) {
    if (error instanceof HttpError) {
      return jsonResponse(error.statusCode, { message: error.message, details: error.details });
    }
    console.error('Unhandled error in accounts handler', error);
    return jsonResponse(500, { message: 'Internal Server Error' });
  }
};
