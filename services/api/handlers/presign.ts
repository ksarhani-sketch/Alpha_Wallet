import { APIGatewayProxyHandlerV2 } from 'aws-lambda';
import { S3Client, PutObjectCommand } from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';
import { env } from '../shared/dynamo.js';

const s3 = new S3Client({});
export const handler: APIGatewayProxyHandlerV2 = async (event) => {
  const userId = event.requestContext.authorizer?.jwt?.claims?.sub || 'demo-user';
  const body = JSON.parse(event.body ?? '{}');
  const key = `u_${userId}/${body.txnId}/${body.filename}`;
  const url = await getSignedUrl(
    s3,
    new PutObjectCommand({ Bucket: env.bucket, Key: key }),
    { expiresIn: 300 },
  );
  return { statusCode: 200, body: JSON.stringify({ uploadUrl: url, objectKey: key }) };
};
