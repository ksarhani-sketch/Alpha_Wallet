import { APIGatewayProxyHandlerV2 } from 'aws-lambda';
import { DeleteCommand, PutCommand, QueryCommand, UpdateCommand } from '@aws-sdk/lib-dynamodb';
import { ddb, env } from '../shared/dynamo.js';
import { HttpError, jsonResponse, parseJson, requireUserId, validate } from '../shared/http.js';

const monthRegex = /^\d{4}-(0[1-9]|1[0-2])$/;

const toPeriodKey = (month: string, categoryId: string | null | undefined) =>
  `${month}#${categoryId ?? 'all'}`;

const buildPeriod = (month: string) => {
  const [year, monthPart] = month.split('-').map(Number);
  const start = new Date(Date.UTC(year, monthPart - 1, 1));
  const end = new Date(Date.UTC(year, monthPart, 0, 23, 59, 59, 999));
  return { periodStart: start.toISOString(), periodEnd: end.toISOString() };
};

interface BudgetPayload {
  month: string;
  categoryId?: string | null;
  currency: string;
  limit: number;
  alertThreshold?: number;
  rollover?: boolean;
}

export const handler: APIGatewayProxyHandlerV2 = async (event) => {
  try {
    const method = event.requestContext.http.method;
    const userId = requireUserId(event);
    const monthParam = event.pathParameters?.month;
    const categoryParam = event.pathParameters?.categoryId;

    if (method === 'GET') {
      if (monthParam) {
        validate(monthRegex.test(monthParam), 400, 'Month must be formatted as YYYY-MM');
        if (categoryParam) {
          const key = toPeriodKey(monthParam, categoryParam);
          const result = await ddb.send(
            new QueryCommand({
              TableName: env.budTable,
              KeyConditionExpression: 'userId = :u AND periodCat = :p',
              ExpressionAttributeValues: { ':u': userId, ':p': key },
              Limit: 1,
            }),
          );
          const budget = result.Items?.[0];
          if (!budget) {
            throw new HttpError(404, 'Budget not found');
          }
          return jsonResponse(200, budget);
        }

        const result = await ddb.send(
          new QueryCommand({
            TableName: env.budTable,
            KeyConditionExpression: 'userId = :u AND begins_with(periodCat, :p)',
            ExpressionAttributeValues: { ':u': userId, ':p': monthParam },
          }),
        );
        return jsonResponse(200, result.Items ?? []);
      }

      const yymm = event.queryStringParameters?.month;
      if (yymm) {
        validate(monthRegex.test(yymm), 400, 'Month must be formatted as YYYY-MM');
      }
      const keyPrefix = yymm ?? new Date().toISOString().slice(0, 7);
      const r = await ddb.send(
        new QueryCommand({
          TableName: env.budTable,
          KeyConditionExpression: 'userId = :u AND begins_with(periodCat, :p)',
          ExpressionAttributeValues: { ':u': userId, ':p': keyPrefix },
        }),
      );
      return jsonResponse(200, r.Items ?? []);
    }

    if (method === 'POST') {
      const body = parseJson<BudgetPayload>(event.body);
      validate(monthRegex.test(body.month), 400, 'Month must be formatted as YYYY-MM');
      validate(typeof body.currency === 'string' && body.currency.trim().length === 3, 400, 'Currency must be a 3-letter ISO code');
      const limit = Number(body.limit);
      validate(Number.isFinite(limit) && limit > 0, 400, 'Budget limit must be a positive number');
      if (body.alertThreshold !== undefined) {
        validate(typeof body.alertThreshold === 'number' && body.alertThreshold > 0 && body.alertThreshold <= 1.5, 400, 'Alert threshold must be between 0 and 1.5');
      }
      const key = toPeriodKey(body.month, body.categoryId ?? null);
      const { periodStart, periodEnd } = buildPeriod(body.month);
      const now = new Date().toISOString();
      const item = {
        userId,
        periodCat: key,
        month: body.month,
        categoryId: body.categoryId ?? null,
        currency: body.currency.toUpperCase(),
        limit,
        alertThreshold: body.alertThreshold ?? 0.9,
        rollover: Boolean(body.rollover),
        periodStart,
        periodEnd,
        createdAt: now,
        updatedAt: now,
      };
      await ddb.send(
        new PutCommand({
          TableName: env.budTable,
          Item: item,
          ConditionExpression: 'attribute_not_exists(periodCat)',
        }),
      );
      return jsonResponse(201, item);
    }

    if (method === 'PUT') {
      validate(Boolean(monthParam), 400, 'Budget month is required');
      validate(monthRegex.test(monthParam!), 400, 'Month must be formatted as YYYY-MM');
      const key = toPeriodKey(monthParam!, categoryParam ?? null);
      const body = parseJson<Partial<BudgetPayload>>(event.body);
      const updates: string[] = [];
      const values: Record<string, unknown> = { ':now': new Date().toISOString() };

      if (body.currency !== undefined) {
        validate(typeof body.currency === 'string' && body.currency.trim().length === 3, 400, 'Currency must be a 3-letter ISO code');
        updates.push('currency = :currency');
        values[':currency'] = body.currency.toUpperCase();
      }

      if (body.limit !== undefined) {
        const limit = Number(body.limit);
        validate(Number.isFinite(limit) && limit > 0, 400, 'Budget limit must be a positive number');
        updates.push('limit = :limit');
        values[':limit'] = limit;
      }

      if (body.alertThreshold !== undefined) {
        validate(typeof body.alertThreshold === 'number' && body.alertThreshold > 0 && body.alertThreshold <= 1.5, 400, 'Alert threshold must be between 0 and 1.5');
        updates.push('alertThreshold = :alert');
        values[':alert'] = body.alertThreshold;
      }

      if (body.rollover !== undefined) {
        updates.push('rollover = :rollover');
        values[':rollover'] = Boolean(body.rollover);
      }

      validate(updates.length > 0, 400, 'No updatable fields provided');
      updates.push('updatedAt = :now');

      const result = await ddb.send(
        new UpdateCommand({
          TableName: env.budTable,
          Key: { userId, periodCat: key },
          ConditionExpression: 'attribute_exists(periodCat)',
          UpdateExpression: `SET ${updates.join(', ')}`,
          ExpressionAttributeValues: values,
          ReturnValues: 'ALL_NEW',
        }),
      );
      return jsonResponse(200, result.Attributes ?? null);
    }

    if (method === 'DELETE') {
      validate(Boolean(monthParam), 400, 'Budget month is required');
      validate(monthRegex.test(monthParam!), 400, 'Month must be formatted as YYYY-MM');
      const key = toPeriodKey(monthParam!, categoryParam ?? null);
      await ddb.send(
        new DeleteCommand({
          TableName: env.budTable,
          Key: { userId, periodCat: key },
          ConditionExpression: 'attribute_exists(periodCat)',
        }),
      );
      return jsonResponse(204, null);
    }

    return jsonResponse(405, { message: 'Method Not Allowed' });
  } catch (error) {
    if (error instanceof HttpError) {
      return jsonResponse(error.statusCode, { message: error.message, details: error.details });
    }
    console.error('Unhandled error in budgets handler', error);
    return jsonResponse(500, { message: 'Internal Server Error' });
  }
};
