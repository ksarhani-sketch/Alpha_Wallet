import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import { DynamoDBDocumentClient, ScanCommand, UpdateCommand } from '@aws-sdk/lib-dynamodb';
import { Handler } from 'aws-lambda';

const client = DynamoDBDocumentClient.from(new DynamoDBClient({}));

const parseFallbackRates = (): Record<string, number> => {
  try {
    return JSON.parse(process.env.FX_RATES_FALLBACK ?? '{}') as Record<string, number>;
  } catch {
    return {};
  }
};

const fetchRemoteRates = async (baseCurrency: string): Promise<Record<string, number>> => {
  try {
    const response = await fetch(`https://open.er-api.com/v6/latest/${encodeURIComponent(baseCurrency)}`);
    if (!response.ok) {
      console.warn(`FX API responded with status ${response.status}`);
      return {};
    }
    const payload = (await response.json()) as { result?: string; rates?: Record<string, number> };
    if (payload.result !== 'success' || !payload.rates) {
      console.warn('FX API payload missing rates');
      return {};
    }
    return payload.rates;
  } catch (error) {
    console.warn('Failed to fetch FX rates', error);
    return {};
  }
};

export const handler: Handler = async () => {
  const table = process.env.TABLE_TRANSACTIONS;
  if (!table) {
    console.warn('Missing TABLE_TRANSACTIONS environment variable.');
    return;
  }

  const baseCurrency = process.env.BASE_CURRENCY ?? 'USD';
  const fallbackRates = parseFallbackRates();
  const remoteRates = await fetchRemoteRates(baseCurrency);
  const mergedRates = { ...fallbackRates, ...remoteRates, [baseCurrency]: 1 };

  let exclusiveStartKey: Record<string, unknown> | undefined;
  do {
    const scan = await client.send(
      new ScanCommand({
        TableName: table,
        ProjectionExpression: '#u, sk, currency, amount, fx_rate_to_base',
        ExpressionAttributeNames: { '#u': 'userId' },
        ExclusiveStartKey: exclusiveStartKey,
      }),
    );
    exclusiveStartKey = scan.LastEvaluatedKey as Record<string, unknown> | undefined;

    for (const item of scan.Items ?? []) {
      const currency = item.currency as string | undefined;
      if (!currency || currency === baseCurrency) continue;
      const rate = mergedRates[currency];
      if (!rate || rate <= 0) continue;
      const currentRate = typeof item.fx_rate_to_base === 'number' ? item.fx_rate_to_base : 0;
      if (Math.abs(currentRate - rate) < 0.0001) continue;
      const amount = typeof item.amount === 'number' ? item.amount : Number(item.amount);
      if (!Number.isFinite(amount)) continue;
      const amountBase = amount * rate;
      await client.send(
        new UpdateCommand({
          TableName: table,
          Key: { userId: item.userId, sk: item.sk },
          UpdateExpression: 'SET fx_rate_to_base = :rate, amount_base = :amountBase, updatedAt = :now',
          ExpressionAttributeValues: {
            ':rate': rate,
            ':amountBase': amountBase,
            ':now': new Date().toISOString(),
          },
        }),
      );
    }
  } while (exclusiveStartKey);
};
