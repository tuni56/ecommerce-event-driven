// DLQ handler — logs failed messages for inspection and alerting
// In production, this could forward to a monitoring system or S3 for analysis

export const handler = async (event) => {
  for (const record of event.Records) {
    console.error("DLQ Message received:", JSON.stringify({
      messageId: record.messageId,
      body: record.body,
      attributes: record.attributes,
      receiveCount: record.attributes?.ApproximateReceiveCount,
    }));
  }

  console.error(`Processed ${event.Records.length} DLQ message(s) — review required`);
};
