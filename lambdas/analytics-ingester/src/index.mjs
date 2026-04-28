import { S3Client, PutObjectCommand } from "@aws-sdk/client-s3";

const s3 = new S3Client();
const BUCKET = process.env.ANALYTICS_BUCKET;

export const handler = async (event) => {
  for (const record of event.Records) {
    const message = JSON.parse(record.body);
    const order = JSON.parse(message.Message || message);

    const now = new Date();
    const partition = `year=${now.getUTCFullYear()}/month=${String(now.getUTCMonth() + 1).padStart(2, "0")}/day=${String(now.getUTCDate()).padStart(2, "0")}`;
    const key = `orders/${partition}/${order.orderId}.json`;

    await s3.send(
      new PutObjectCommand({
        Bucket: BUCKET,
        Key: key,
        Body: JSON.stringify({ ...order, ingestedAt: now.toISOString() }),
        ContentType: "application/json",
      })
    );

    console.log(`Ingested order ${order.orderId} to s3://${BUCKET}/${key}`);
  }
};
