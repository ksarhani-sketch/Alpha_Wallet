import { APIGatewayProxyHandlerV2 } from 'aws-lambda';
import { S3Client, PutObjectCommand } from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';
import { env } from '../shared/dynamo.js';
import { HttpError, jsonResponse, parseJson, requireUserId, validate } from '../shared/http.js';

const s3 = new S3Client({});
const allowedContentTypes = new Set([
  'image/jpeg',
  'image/png',
  'image/webp',
  'application/pdf',
]);
const maxBytes = 5 * 1024 * 1024; // 5 MB

interface PresignPayload {
  txnId: string;
  filename: string;
  contentType: string;
  contentLength?: number;
}

const sanitiseFilename = (filename: string) => {
  validate(!filename.includes('..'), 400, 'Filename may not contain relative paths');
  const cleaned = filename.replace(/[\\\n\r]/g, '').trim();
  validate(cleaned.length > 0, 400, 'Filename cannot be empty');
  return cleaned;
};

export const handler: APIGatewayProxyHandlerV2 = async (event) => {
  try {
    const userId = requireUserId(event);
    const body = parseJson<PresignPayload>(event.body);
    validate(typeof body.txnId === 'string' && body.txnId, 400, 'txnId is required');
    validate(typeof body.contentType === 'string', 400, 'contentType is required');
    validate(allowedContentTypes.has(body.contentType), 400, 'Unsupported content type');
    if (body.contentLength !== undefined) {
      const length = Number(body.contentLength);
      validate(Number.isFinite(length), 400, 'contentLength must be numeric');
      validate(length <= maxBytes, 400, 'Attachments are limited to 5MB');
    }
    const filename = sanitiseFilename(body.filename);

    const key = `u_${userId}/${body.txnId}/${encodeURIComponent(filename)}`;
    const url = await getSignedUrl(
      s3,
      new PutObjectCommand({
        Bucket: env.bucket,
        Key: key,
        ContentType: body.contentType,
        Metadata: {
          userId,
          txnId: body.txnId,
        },
      }),
      { expiresIn: 300 },
    );
    return jsonResponse(200, {
      uploadUrl: url,
      objectKey: key,
      expiresInSeconds: 300,
      bucket: env.bucket,
    });
  } catch (error) {
    if (error instanceof HttpError) {
      return jsonResponse(error.statusCode, { message: error.message });
    }
    console.error('Unhandled error in presign handler', error);
    return jsonResponse(500, { message: 'Internal Server Error' });
  }
};
