import { APIGatewayProxyHandlerV2 } from 'aws-lambda';
import { GetCommand, PutCommand, UpdateCommand } from '@aws-sdk/lib-dynamodb';
import bcrypt from 'bcryptjs';
import { randomUUID } from 'node:crypto';
import { ddb, env } from '../shared/dynamo.js';
import { HttpError, jsonResponse, parseJson } from '../shared/http.js';
import { issueTokenPair, verifyRefreshToken } from '../shared/auth.js';

interface RegisterPayload {
  email: string;
  password: string;
  displayName?: string;
}

interface LoginPayload {
  email: string;
  password: string;
}

interface RefreshPayload {
  refreshToken: string;
}

const normaliseEmail = (input: unknown): string => {
  if (typeof input !== 'string') {
    throw new HttpError(400, 'Email address is required');
  }
  const email = input.trim().toLowerCase();
  if (!/^\S+@\S+\.\S+$/.test(email)) {
    throw new HttpError(400, 'Email address is invalid');
  }
  return email;
};

const normalisePassword = (input: unknown): string => {
  if (typeof input !== 'string' || input.length < 8) {
    throw new HttpError(400, 'Password must be at least 8 characters long');
  }
  return input;
};

const getUserByEmail = async (email: string) => {
  const response = await ddb.send(
    new GetCommand({
      TableName: env.userTable,
      Key: { email },
    }),
  );
  return response.Item as Record<string, unknown> | undefined;
};

const hashPassword = async (password: string) => {
  const rounds = Number.parseInt(process.env.BCRYPT_ROUNDS ?? '12', 10);
  if (!Number.isFinite(rounds) || rounds < 4) {
    throw new Error('BCRYPT_ROUNDS must be a positive integer greater than 3');
  }
  return bcrypt.hash(password, rounds);
};

const mapUserResponse = (item: Record<string, unknown>) => ({
  userId: item.userId,
  email: item.email,
  displayName: typeof item.displayName === 'string' ? item.displayName : null,
  createdAt: item.createdAt,
  updatedAt: item.updatedAt,
  lastLoginAt: item.lastLoginAt ?? null,
});

export const handler: APIGatewayProxyHandlerV2 = async (event) => {
  try {
    const method = event.requestContext.http.method;
    const path = (event.requestContext.http.path ?? '').replace(/\/+$/, '');

    if (method === 'POST' && path.endsWith('/auth/register')) {
      const body = parseJson<RegisterPayload>(event.body);
      const email = normaliseEmail(body.email);
      const password = normalisePassword(body.password);
      const now = new Date().toISOString();
      const passwordHash = await hashPassword(password);
      const item = {
        email,
        userId: randomUUID(),
        passwordHash,
        displayName: typeof body.displayName === 'string' ? body.displayName.trim() || null : null,
        createdAt: now,
        updatedAt: now,
        lastLoginAt: now,
      };
      try {
        await ddb.send(
          new PutCommand({
            TableName: env.userTable,
            Item: item,
            ConditionExpression: 'attribute_not_exists(email)',
          }),
        );
      } catch (error) {
        if ((error as { name?: string }).name === 'ConditionalCheckFailedException') {
          throw new HttpError(409, 'An account with this email already exists');
        }
        throw error;
      }

      const tokens = issueTokenPair(item.userId, { email });
      return jsonResponse(201, {
        user: mapUserResponse(item),
        tokens,
      });
    }

    if (method === 'POST' && path.endsWith('/auth/login')) {
      const body = parseJson<LoginPayload>(event.body);
      const email = normaliseEmail(body.email);
      const password = normalisePassword(body.password);

      const user = await getUserByEmail(email);
      if (!user) {
        throw new HttpError(401, 'Invalid email or password');
      }
      const hash = user.passwordHash as string | undefined;
      if (!hash || !(await bcrypt.compare(password, hash))) {
        throw new HttpError(401, 'Invalid email or password');
      }

      const loginTimestamp = new Date().toISOString();
      await ddb.send(
        new UpdateCommand({
          TableName: env.userTable,
          Key: { email },
          UpdateExpression: 'SET lastLoginAt = :now',
          ExpressionAttributeValues: { ':now': loginTimestamp },
        }),
      );

      const tokens = issueTokenPair(user.userId as string, { email });
      const userForResponse = { ...user, lastLoginAt: loginTimestamp };
      return jsonResponse(200, {
        user: mapUserResponse(userForResponse),
        tokens,
      });
    }

    if (method === 'POST' && path.endsWith('/auth/refresh')) {
      const body = parseJson<RefreshPayload>(event.body);
      if (typeof body.refreshToken !== 'string' || body.refreshToken.trim().length === 0) {
        throw new HttpError(400, 'Refresh token is required');
      }
      let payload;
      try {
        payload = verifyRefreshToken(body.refreshToken.trim());
      } catch (error) {
        throw new HttpError(401, (error as Error).message);
      }
      const email = typeof payload.email === 'string' ? String(payload.email).toLowerCase() : undefined;
      const userId = typeof payload.sub === 'string' ? payload.sub : undefined;
      if (!userId || !email) {
        throw new HttpError(401, 'Invalid refresh token');
      }
      const user = await getUserByEmail(email);
      if (!user || user.userId !== userId) {
        throw new HttpError(401, 'Invalid refresh token');
      }
      const tokens = issueTokenPair(userId, { email });
      return jsonResponse(200, { user: mapUserResponse(user), tokens });
    }

    throw new HttpError(404, 'Not found');
  } catch (error) {
    if (error instanceof HttpError) {
      return jsonResponse(error.statusCode, { message: error.message });
    }
    console.error('Unhandled auth error', error);
    return jsonResponse(500, { message: 'Internal server error' });
  }
};
