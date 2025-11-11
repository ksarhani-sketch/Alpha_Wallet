import { APIGatewayProxyEventV2 } from 'aws-lambda';
import { verifyAccessToken } from './auth.js';

const allowDemoMode = process.env.ALLOW_DEMO_MODE === 'true';
const demoUserId = process.env.DEMO_USER_ID ?? 'demo-user';

export class HttpError extends Error {
  constructor(public readonly statusCode: number, message: string, public readonly details?: unknown) {
    super(message);
  }
}

export const jsonResponse = (statusCode: number, body: unknown) => ({
  statusCode,
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify(body ?? null),
});

export const requireUserId = (event: APIGatewayProxyEventV2): string => {
  const header = event.headers?.authorization ?? event.headers?.Authorization;
  if (typeof header === 'string') {
    const match = header.match(/^Bearer\s+(.+)$/i);
    if (!match) {
      throw new HttpError(401, 'Authorization header is malformed');
    }
    try {
      const payload = verifyAccessToken(match[1].trim());
      const userId = typeof payload.sub === 'string' ? payload.sub : undefined;
      if (!userId) {
        throw new HttpError(401, 'Token missing subject');
      }
      return userId;
    } catch (error) {
      throw new HttpError(401, (error as Error).message);
    }
  }

  const userId = event.requestContext.authorizer?.jwt?.claims?.sub;
  if (typeof userId === 'string' && userId.trim().length > 0) {
    return userId;
  }

  if (allowDemoMode) {
    return demoUserId;
  }

  throw new HttpError(401, 'Authentication required');
};

export const parseJson = <T>(body: string | null | undefined): T => {
  if (!body) {
    throw new HttpError(400, 'Request body is required');
  }
  try {
    return JSON.parse(body) as T;
  } catch (error) {
    throw new HttpError(400, 'Request body must be valid JSON');
  }
};

export const validate = (condition: boolean, status: number, message: string): void => {
  if (!condition) {
    throw new HttpError(status, message);
  }
};
