#!/usr/bin/env bash
# Demo script for AWS User Group Arequipa
# Publishes a sample order to SNS and shows the event flowing through both paths

set -euo pipefail

REGION="us-east-2"
ENV="dev"
PREFIX="ecommerce-ed-${ENV}"

# Get SNS topic ARN from Terraform output
TOPIC_ARN=$(cd ../terraform/environments/dev && terraform output -raw sns_topic_arn)

ORDER_ID="ORD-$(date +%s)"

ORDER_PAYLOAD=$(cat <<EOF
{
  "orderId": "${ORDER_ID}",
  "customerId": "CUST-42",
  "items": [
    {"productId": "PROD-001", "name": "Wireless Keyboard", "quantity": 1, "price": 49.99},
    {"productId": "PROD-002", "name": "USB-C Hub", "quantity": 2, "price": 29.99}
  ],
  "total": 109.97,
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
)

echo "============================================"
echo "  E-Commerce Event-Driven Demo"
echo "============================================"
echo ""
echo "1. Publishing order ${ORDER_ID} to SNS..."
echo ""

aws sns publish \
  --region "${REGION}" \
  --topic-arn "${TOPIC_ARN}" \
  --message "${ORDER_PAYLOAD}" \
  --message-attributes '{"eventType":{"DataType":"String","StringValue":"OrderCreated"}}' \
  --output json

echo ""
echo "2. Waiting 5 seconds for processing..."
sleep 5

echo ""
echo "3. Checking DynamoDB (real-time path)..."
echo "   Orders table:"
aws dynamodb get-item \
  --region "${REGION}" \
  --table-name "${PREFIX}-orders" \
  --key "{\"orderId\": {\"S\": \"${ORDER_ID}\"}}" \
  --output json 2>/dev/null || echo "   (not found yet)"

echo ""
echo "4. Checking S3 (batch path)..."
BUCKET=$(cd ../terraform/environments/dev && terraform output -raw analytics_bucket)
echo "   Looking for order in s3://${BUCKET}/orders/..."
aws s3 ls "s3://${BUCKET}/orders/" --recursive --region "${REGION}" 2>/dev/null | tail -5 || echo "   (not found yet)"

echo ""
echo "5. Checking DLQ (should be empty)..."
QUEUE_URL="https://sqs.${REGION}.amazonaws.com/$(aws sts get-caller-identity --query Account --output text)/${PREFIX}-order-processing-dlq"
MESSAGES=$(aws sqs get-queue-attributes \
  --region "${REGION}" \
  --queue-url "${QUEUE_URL}" \
  --attribute-names ApproximateNumberOfMessagesVisible \
  --query "Attributes.ApproximateNumberOfMessagesVisible" \
  --output text 2>/dev/null || echo "0")
echo "   Messages in DLQ: ${MESSAGES}"

echo ""
echo "============================================"
echo "  Demo complete!"
echo "============================================"
