import jwt, { JwtPayload } from 'jsonwebtoken';

const accessSecret = process.env.JWT_SECRET;
const refreshSecret = process.env.JWT_REFRESH_SECRET ?? accessSecret;
const accessTtl = process.env.JWT_ACCESS_EXPIRES_IN ?? '1h';
const refreshTtl = process.env.JWT_REFRESH_EXPIRES_IN ?? '30d';

const ensureSecret = (secret: string | undefined, name: string): string => {
  if (!secret || secret.length === 0) {
    throw new Error(`${name} is not configured`);
  }
  return secret;
};

const decodeExpiry = (token: string): string | null => {
  const payload = jwt.decode(token) as JwtPayload | null;
  if (!payload?.exp) {
    return null;
  }
  return new Date(payload.exp * 1000).toISOString();
};

export interface SignedToken {
  token: string;
  expiresAt: string | null;
}

export interface TokenPair {
  accessToken: SignedToken;
  refreshToken: SignedToken;
}

export const signAccessToken = (userId: string, claims?: Record<string, unknown>): SignedToken => {
  const secret = ensureSecret(accessSecret, 'JWT_SECRET');
  const payload = { sub: userId, type: 'access', ...(claims ?? {}) } satisfies Record<string, unknown>;
  const token = jwt.sign(payload, secret, { expiresIn: accessTtl });
  return { token, expiresAt: decodeExpiry(token) };
};

export const signRefreshToken = (userId: string, claims?: Record<string, unknown>): SignedToken => {
  const secret = ensureSecret(refreshSecret, 'JWT_REFRESH_SECRET');
  const payload = { sub: userId, type: 'refresh', ...(claims ?? {}) } satisfies Record<string, unknown>;
  const token = jwt.sign(payload, secret, { expiresIn: refreshTtl });
  return { token, expiresAt: decodeExpiry(token) };
};

export const issueTokenPair = (userId: string, claims?: Record<string, unknown>): TokenPair => ({
  accessToken: signAccessToken(userId, claims),
  refreshToken: signRefreshToken(userId, claims),
});

const verifyToken = (token: string, expectedType: 'access' | 'refresh'): JwtPayload => {
  const secret =
    expectedType === 'access'
      ? ensureSecret(accessSecret, 'JWT_SECRET')
      : ensureSecret(refreshSecret, 'JWT_REFRESH_SECRET');
  const payload = jwt.verify(token, secret) as JwtPayload;
  if (payload.type !== expectedType) {
    throw new Error('Token type mismatch');
  }
  if (typeof payload.sub !== 'string' || payload.sub.trim().length === 0) {
    throw new Error('Token subject missing');
  }
  return payload;
};

export const verifyAccessToken = (token: string): JwtPayload => verifyToken(token, 'access');

export const verifyRefreshToken = (token: string): JwtPayload => verifyToken(token, 'refresh');
