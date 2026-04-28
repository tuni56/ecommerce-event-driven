import { DynamoDBClient } from "@aws-sdk/client-dynamodb";
import { PutCommand, DynamoDBDocumentClient } from "@aws-sdk/lib-dynamodb";

const client = DynamoDBDocumentClient.from(new DynamoDBClient());
const TABLE = process.env.ORDERS_TABLE;

export const handler = async (event) => {
  for (const record of event.Records) {
    const message = JSON.parse(record.body);
    // SNS wraps the payload in a Message field
    const order = JSON.parse(message.Message || message);

    console.log("Processing order:", order.orderId);

    // Idempotent write — conditional on orderId not existing (ADR-006)
    await client.send(
      new PutCommand({
        TableName: TABLE,
        Item: {
          orderId: order.orderId,
          customerId: order.customerId,
          items: order.items,
          total: order.total,
          status: "CONFIRMED",
          createdAt: new Date().toISOString(),
        },
        ConditionExpression: "attribute_not_exists(orderId)",
      })
    ).catch((err) => {
      if (err.name === "ConditionalCheckFailedException") {
        console.log(`Order ${order.orderId} already exists — skipping (idempotent)`);
        return;
      }
      throw err;
    });
  }
};
