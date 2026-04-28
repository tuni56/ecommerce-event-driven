import { DynamoDBClient } from "@aws-sdk/client-dynamodb";
import { UpdateCommand, DynamoDBDocumentClient } from "@aws-sdk/lib-dynamodb";

const client = DynamoDBDocumentClient.from(new DynamoDBClient());
const TABLE = process.env.INVENTORY_TABLE;

export const handler = async (event) => {
  for (const record of event.Records) {
    const message = JSON.parse(record.body);
    const order = JSON.parse(message.Message || message);

    console.log("Updating inventory for order:", order.orderId);

    for (const item of order.items) {
      await client.send(
        new UpdateCommand({
          TableName: TABLE,
          Key: { productId: item.productId },
          UpdateExpression: "ADD stock :dec",
          ExpressionAttributeValues: { ":dec": -item.quantity },
        })
      );
      console.log(`Product ${item.productId}: decremented by ${item.quantity}`);
    }
  }
};
