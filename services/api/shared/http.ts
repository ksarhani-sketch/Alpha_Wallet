import { APIGatewayProxyEventV2 } from 'aws-lambda';

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
  const userId = event.requestContext.authorizer?.jwt?.claims?.sub;
  if (!userId || typeof userId !== 'string' || userId.trim().length === 0) {
    throw new HttpError(401, 'Missing or invalid authentication context');
  }
  return userId;
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
