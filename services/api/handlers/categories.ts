import { APIGatewayProxyHandlerV2 } from 'aws-lambda';
import { DeleteCommand, PutCommand, QueryCommand, UpdateCommand } from '@aws-sdk/lib-dynamodb';
import { randomUUID } from 'node:crypto';
import { ddb, env } from '../shared/dynamo.js';
import { HttpError, jsonResponse, parseJson, requireUserId, validate } from '../shared/http.js';

const allowedCategoryTypes = new Set(['expense', 'income']);

interface CategoryPayload {
  name: string;
  type: string;
  color?: string;
  icon?: string;
}

const normaliseCategoryType = (type: unknown): string => {
  validate(typeof type === 'string', 400, 'Category type is required');
  const value = type.toLowerCase();
  validate(allowedCategoryTypes.has(value), 400, 'Category type must be "expense" or "income"');
  return value;
};

export const handler: APIGatewayProxyHandlerV2 = async (event) => {
  try {
    const method = event.requestContext.http.method;
    const userId = requireUserId(event);
    const categoryId = event.pathParameters?.categoryId;

    if (method === 'GET') {
      if (categoryId) {
        const result = await ddb.send(
          new QueryCommand({
            TableName: env.catTable,
            KeyConditionExpression: 'userId = :u AND categoryId = :c',
            ExpressionAttributeValues: { ':u': userId, ':c': categoryId },
            Limit: 1,
          }),
        );
        const category = result.Items?.[0];
        if (!category) {
          throw new HttpError(404, 'Category not found');
        }
        return jsonResponse(200, category);
      }

      const r = await ddb.send(
        new QueryCommand({
          TableName: env.catTable,
          KeyConditionExpression: 'userId = :u',
          ExpressionAttributeValues: { ':u': userId },
        }),
      );
      return jsonResponse(200, r.Items ?? []);
    }

    if (method === 'POST') {
      const body = parseJson<CategoryPayload>(event.body);
      validate(typeof body.name === 'string' && body.name.trim().length > 1, 400, 'Category name is required');
      const type = normaliseCategoryType(body.type);
      const now = new Date().toISOString();

      const item = {
        userId,
        categoryId: randomUUID(),
        name: body.name.trim(),
        type,
        color: body.color ?? '#36c',
        icon: body.icon ?? '📦',
        createdAt: now,
        updatedAt: now,
      };
      await ddb.send(new PutCommand({ TableName: env.catTable, Item: item }));
      return jsonResponse(201, item);
    }

    if (method === 'PUT') {
      validate(Boolean(categoryId), 400, 'Category identifier is required');
      const body = parseJson<Partial<CategoryPayload>>(event.body);
      const updates: string[] = [];
      const values: Record<string, unknown> = { ':now': new Date().toISOString() };

      if (typeof body.name === 'string') {
        validate(body.name.trim().length > 1, 400, 'Category name cannot be empty');
        updates.push('name = :name');
        values[':name'] = body.name.trim();
      }

      if (body.type !== undefined) {
        updates.push('type = :type');
        values[':type'] = normaliseCategoryType(body.type);
      }

      if (typeof body.color === 'string') {
        updates.push('color = :color');
        values[':color'] = body.color;
      }

      if (typeof body.icon === 'string') {
        updates.push('icon = :icon');
        values[':icon'] = body.icon;
      }

      validate(updates.length > 0, 400, 'No updatable fields provided');
      updates.push('updatedAt = :now');

      const result = await ddb.send(
        new UpdateCommand({
          TableName: env.catTable,
          Key: { userId, categoryId },
          ConditionExpression: 'attribute_exists(categoryId)',
          UpdateExpression: `SET ${updates.join(', ')}`,
          ExpressionAttributeValues: values,
          ReturnValues: 'ALL_NEW',
        }),
      );
      return jsonResponse(200, result.Attributes);
    }

    if (method === 'DELETE') {
      validate(Boolean(categoryId), 400, 'Category identifier is required');
      const transactions = await ddb.send(
        new QueryCommand({
          TableName: env.txTable,
          KeyConditionExpression: 'userId = :u',
          ExpressionAttributeValues: {
            ':u': userId,
            ':category': categoryId,
          },
          FilterExpression: 'categoryId = :category',
          Limit: 1,
        }),
      );
      validate((transactions.Items?.length ?? 0) === 0, 409, 'Category cannot be deleted while transactions exist');

      await ddb.send(
        new DeleteCommand({
          TableName: env.catTable,
          Key: { userId, categoryId },
          ConditionExpression: 'attribute_exists(categoryId)',
        }),
      );
      return jsonResponse(204, null);
    }

    return jsonResponse(405, { message: 'Method Not Allowed' });
  } catch (error) {
    if (error instanceof HttpError) {
      return jsonResponse(error.statusCode, { message: error.message, details: error.details });
    }
    console.error('Unhandled error in categories handler', error);
    return jsonResponse(500, { message: 'Internal Server Error' });
  }
};
