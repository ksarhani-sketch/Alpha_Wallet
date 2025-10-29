import { APIGatewayProxyHandlerV2 } from 'aws-lambda';
import { GetCommand, QueryCommand, TransactWriteCommand } from '@aws-sdk/lib-dynamodb';
import { randomUUID } from 'node:crypto';
import { ddb, env } from '../shared/dynamo.js';
import { HttpError, jsonResponse, parseJson, requireUserId, validate } from '../shared/http.js';

const allowedTypes = new Set(['expense', 'income']);

interface TransactionPayload {
  accountId: string;
  categoryId: string;
  type: 'expense' | 'income';
  amount: number;
  currency?: string;
  occurredAt?: string;
  fx_rate_to_base?: number;
  note?: string;
  tags?: string[];
}

const normaliseIso = (value: unknown, field: string): string => {
  validate(typeof value === 'string' && !Number.isNaN(Date.parse(value)), 400, `${field} must be a valid ISO8601 timestamp`);
  return new Date(value).toISOString();
};

const fetchAccount = async (userId: string, accountId: string) => {
  const { Item } = await ddb.send(
    new GetCommand({ TableName: env.accTable, Key: { userId, accountId } }),
  );
  if (!Item) {
    throw new HttpError(404, 'Account not found');
  }
  return Item;
};

const fetchCategory = async (userId: string, categoryId: string) => {
  const { Item } = await ddb.send(
    new GetCommand({ TableName: env.catTable, Key: { userId, categoryId } }),
  );
  if (!Item) {
    throw new HttpError(404, 'Category not found');
  }
  return Item;
};

const fetchTransactionById = async (userId: string, txnId: string) => {
  const result = await ddb.send(
    new QueryCommand({
      TableName: env.txTable,
      KeyConditionExpression: 'userId = :u',
      ExpressionAttributeValues: { ':u': userId, ':t': txnId },
      FilterExpression: 'txnId = :t',
      Limit: 1,
    }),
  );
  return result.Items?.[0] ?? null;
};

const typeToDelta = (type: string, amount: number) => (type === 'expense' ? -amount : amount);

export const handler: APIGatewayProxyHandlerV2 = async (event) => {
  try {
    const method = event.requestContext.http.method;
    const userId = requireUserId(event);
    const txnId = event.pathParameters?.txnId;

    if (method === 'GET') {
      if (txnId) {
        const txn = await fetchTransactionById(userId, txnId);
        if (!txn) {
          throw new HttpError(404, 'Transaction not found');
        }
        return jsonResponse(200, txn);
      }

      const now = new Date();
      const from = event.queryStringParameters?.from ?? new Date(now.getFullYear(), now.getMonth(), 1).toISOString();
      const to = event.queryStringParameters?.to ?? now.toISOString();
      validate(!Number.isNaN(Date.parse(from)), 400, 'from must be a valid ISO8601 timestamp');
      validate(!Number.isNaN(Date.parse(to)), 400, 'to must be a valid ISO8601 timestamp');

      const r = await ddb.send(
        new QueryCommand({
          TableName: env.txTable,
          KeyConditionExpression: 'userId = :u AND sk BETWEEN :from AND :to',
          ExpressionAttributeValues: {
            ':u': userId,
            ':from': `DT#${new Date(from).toISOString()}`,
            ':to': `DT#${new Date(to).toISOString()}`,
          },
        }),
      );
      return jsonResponse(200, r.Items ?? []);
    }

    if (method === 'POST') {
      const body = parseJson<TransactionPayload>(event.body);
      validate(typeof body.accountId === 'string' && body.accountId, 400, 'Account ID is required');
      validate(typeof body.categoryId === 'string' && body.categoryId, 400, 'Category ID is required');
      validate(typeof body.type === 'string', 400, 'Transaction type is required');
      const type = body.type.toLowerCase();
      validate(allowedTypes.has(type), 400, 'Transaction type must be "expense" or "income"');
      const amount = Number(body.amount);
      validate(Number.isFinite(amount) && amount > 0, 400, 'Amount must be a positive number');
      const occurredAt = body.occurredAt ? normaliseIso(body.occurredAt, 'occurredAt') : new Date().toISOString();
      const fx = body.fx_rate_to_base === undefined ? 1 : Number(body.fx_rate_to_base);
      validate(Number.isFinite(fx) && fx > 0, 400, 'fx_rate_to_base must be a positive number');

      const account = await fetchAccount(userId, body.accountId);
      if (body.currency) {
        validate(body.currency.toUpperCase() === account.currency, 400, 'Transaction currency must match account currency');
      }
      const category = await fetchCategory(userId, body.categoryId);
      validate(category.type === type, 400, `Transaction type must match category type (${category.type})`);

      const txnIdNew = randomUUID();
      const sk = `DT#${occurredAt}#TX#${txnIdNew}`;
      const nowIso = new Date().toISOString();
      const item = {
        userId,
        sk,
        txnId: txnIdNew,
        accountId: body.accountId,
        categoryId: body.categoryId,
        type,
        amount,
        currency: account.currency,
        fx_rate_to_base: fx,
        amount_base: amount * fx,
        note: body.note ?? null,
        tags: Array.isArray(body.tags) ? body.tags.filter((t) => typeof t === 'string' && t.trim()).map((t) => t.trim()) : [],
        occurredAt,
        createdAt: nowIso,
        updatedAt: nowIso,
      };

      const delta = typeToDelta(type, amount);
      await ddb.send(
        new TransactWriteCommand({
          TransactItems: [
            { Put: { TableName: env.txTable, Item: item } },
            {
              Update: {
                TableName: env.accTable,
                Key: { userId, accountId: body.accountId },
                UpdateExpression: 'SET currentBalance = if_not_exists(currentBalance, :zero) + :delta, updatedAt = :now',
                ExpressionAttributeValues: {
                  ':delta': delta,
                  ':zero': 0,
                  ':now': nowIso,
                },
                ConditionExpression: 'attribute_exists(accountId)',
              },
            },
          ],
        }),
      );

      return jsonResponse(201, item);
    }

    if (method === 'PUT') {
      validate(Boolean(txnId), 400, 'Transaction ID is required');
      const existing = await fetchTransactionById(userId, txnId!);
      if (!existing) {
        throw new HttpError(404, 'Transaction not found');
      }

      const body = parseJson<Partial<TransactionPayload>>(event.body);
      validate(
        Object.keys(body).length > 0,
        400,
        'No updatable fields provided',
      );

      if (body.accountId !== undefined) {
        validate(typeof body.accountId === 'string' && body.accountId, 400, 'Account ID cannot be empty');
      }
      const targetAccountId = body.accountId ?? existing.accountId;
      const account = await fetchAccount(userId, targetAccountId);
      if (body.type !== undefined) {
        validate(typeof body.type === 'string', 400, 'Transaction type must be a string');
      }
      const newType = body.type ? body.type.toLowerCase() : existing.type;
      validate(allowedTypes.has(newType), 400, 'Transaction type must be "expense" or "income"');

      if (body.categoryId !== undefined) {
        validate(typeof body.categoryId === 'string' && body.categoryId, 400, 'Category ID cannot be empty');
      }
      const targetCategoryId = body.categoryId ?? existing.categoryId;
      const category = await fetchCategory(userId, targetCategoryId);
      validate(category.type === newType, 400, 'Transaction type must match category type');

      const newAmount = body.amount !== undefined ? Number(body.amount) : existing.amount;
      validate(Number.isFinite(newAmount) && newAmount > 0, 400, 'Amount must be a positive number');

      const newFx = body.fx_rate_to_base !== undefined ? Number(body.fx_rate_to_base) : existing.fx_rate_to_base ?? 1;
      validate(Number.isFinite(newFx) && newFx > 0, 400, 'fx_rate_to_base must be a positive number');

      if (body.currency) {
        validate(body.currency.toUpperCase() === account.currency, 400, 'Transaction currency must match account currency');
      }

      const newOccurredAt = body.occurredAt ? normaliseIso(body.occurredAt, 'occurredAt') : existing.occurredAt;
      const newNote = body.note !== undefined ? body.note ?? null : existing.note ?? null;
      const newTags = body.tags !== undefined
        ? (Array.isArray(body.tags)
            ? body.tags.filter((t) => typeof t === 'string' && t.trim()).map((t) => t.trim())
            : (() => {
                throw new HttpError(400, 'tags must be an array of strings');
              })())
        : existing.tags ?? [];

      const newAmountBase = newAmount * newFx;
      const newSk = `DT#${newOccurredAt}#TX#${existing.txnId}`;
      const nowIso = new Date().toISOString();

      const newItem = {
        ...existing,
        sk: newSk,
        accountId: targetAccountId,
        categoryId: targetCategoryId,
        type: newType,
        amount: newAmount,
        currency: account.currency,
        fx_rate_to_base: newFx,
        amount_base: newAmountBase,
        note: newNote,
        tags: newTags,
        occurredAt: newOccurredAt,
        updatedAt: nowIso,
      };

      const transactItems: Parameters<TransactWriteCommand['constructor']>[0]['TransactItems'] = [];

      if (newSk !== existing.sk) {
        transactItems.push({
          Delete: {
            TableName: env.txTable,
            Key: { userId, sk: existing.sk },
            ConditionExpression: 'attribute_exists(sk)',
          },
        });
        transactItems.push({
          Put: {
            TableName: env.txTable,
            Item: newItem,
            ConditionExpression: 'attribute_not_exists(sk)',
          },
        });
      } else {
        transactItems.push({
          Put: {
            TableName: env.txTable,
            Item: newItem,
            ConditionExpression: 'attribute_exists(sk)',
          },
        });
      }

      const balanceAdjustments: Record<string, number> = {};
      const undo = -typeToDelta(existing.type, existing.amount);
      balanceAdjustments[existing.accountId] = (balanceAdjustments[existing.accountId] ?? 0) + undo;
      const apply = typeToDelta(newType, newAmount);
      balanceAdjustments[targetAccountId] = (balanceAdjustments[targetAccountId] ?? 0) + apply;

      for (const [accId, delta] of Object.entries(balanceAdjustments)) {
        if (delta === 0) continue;
        transactItems.push({
          Update: {
            TableName: env.accTable,
            Key: { userId, accountId: accId },
            UpdateExpression: 'SET currentBalance = if_not_exists(currentBalance, :zero) + :delta, updatedAt = :now',
            ExpressionAttributeValues: {
              ':zero': 0,
              ':delta': delta,
              ':now': nowIso,
            },
            ConditionExpression: 'attribute_exists(accountId)',
          },
        });
      }

      await ddb.send(new TransactWriteCommand({ TransactItems: transactItems }));

      const updated = await fetchTransactionById(userId, existing.txnId);
      return jsonResponse(200, updated ?? null);
    }

    if (method === 'DELETE') {
      validate(Boolean(txnId), 400, 'Transaction ID is required');
      const existing = await fetchTransactionById(userId, txnId!);
      if (!existing) {
        throw new HttpError(404, 'Transaction not found');
      }

      const delta = -typeToDelta(existing.type, existing.amount);
      const nowIso = new Date().toISOString();
      await ddb.send(
        new TransactWriteCommand({
          TransactItems: [
            {
              Delete: {
                TableName: env.txTable,
                Key: { userId, sk: existing.sk },
                ConditionExpression: 'attribute_exists(sk)',
              },
            },
            {
              Update: {
                TableName: env.accTable,
                Key: { userId, accountId: existing.accountId },
                UpdateExpression: 'SET currentBalance = if_not_exists(currentBalance, :zero) + :delta, updatedAt = :now',
                ExpressionAttributeValues: {
                  ':zero': 0,
                  ':delta': delta,
                  ':now': nowIso,
                },
                ConditionExpression: 'attribute_exists(accountId)',
              },
            },
          ],
        }),
      );

      return jsonResponse(204, null);
    }

    return jsonResponse(405, { message: 'Method Not Allowed' });
  } catch (error) {
    if (error instanceof HttpError) {
      return jsonResponse(error.statusCode, { message: error.message, details: error.details });
    }
    console.error('Unhandled error in transactions handler', error);
    return jsonResponse(500, { message: 'Internal Server Error' });
  }
};
