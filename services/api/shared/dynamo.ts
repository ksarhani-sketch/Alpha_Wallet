import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import { DynamoDBDocumentClient } from '@aws-sdk/lib-dynamodb';

export const ddb = DynamoDBDocumentClient.from(new DynamoDBClient({}));
export const env = {
  txTable: process.env.TABLE_TRANSACTIONS!,
  accTable: process.env.TABLE_ACCOUNTS!,
  catTable: process.env.TABLE_CATEGORIES!,
  budTable: process.env.TABLE_BUDGETS!,
  userTable: process.env.TABLE_USERS!,
  bucket: process.env.BUCKET_ATTACHMENTS!,
};
