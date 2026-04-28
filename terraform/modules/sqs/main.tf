# SQS Queue + DLQ pair module
# Every queue gets a DLQ — no exceptions (see ADR-002)

variable "project" {
  description = "Project name prefix"
  type        = string
}

variable "name" {
  description = "Queue name suffix"
  type        = string
}

variable "subscribe_to_sns" {
  description = "Whether to create an SNS subscription"
  type        = bool
  default     = false
}

variable "sns_topic_arn" {
  description = "SNS topic ARN to subscribe to"
  type        = string
  default     = ""
}

variable "visibility_timeout" {
  description = "Visibility timeout in seconds (should be >= 6x Lambda timeout)"
  type        = number
  default     = 60
}

variable "max_receive_count" {
  description = "Number of receives before sending to DLQ"
  type        = number
  default     = 3
}

variable "dlq_retention_seconds" {
  description = "DLQ message retention in seconds"
  type        = number
  default     = 1209600 # 14 days
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}

# --- DLQ ---
resource "aws_sqs_queue" "dlq" {
  name                      = "${var.project}-${var.name}-dlq"
  message_retention_seconds = var.dlq_retention_seconds
  tags                      = var.tags
}

# --- Main Queue ---
resource "aws_sqs_queue" "this" {
  name                       = "${var.project}-${var.name}"
  visibility_timeout_seconds = var.visibility_timeout
  message_retention_seconds  = 345600 # 4 days

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq.arn
    maxReceiveCount     = var.max_receive_count
  })

  tags = var.tags
}

# --- SNS Subscription (optional) ---
resource "aws_sns_topic_subscription" "this" {
  count     = var.subscribe_to_sns ? 1 : 0
  topic_arn = var.sns_topic_arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.this.arn
}

resource "aws_sqs_queue_policy" "sns_publish" {
  count     = var.subscribe_to_sns ? 1 : 0
  queue_url = aws_sqs_queue.this.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "sns.amazonaws.com" }
      Action    = "sqs:SendMessage"
      Resource  = aws_sqs_queue.this.arn
      Condition = {
        ArnEquals = { "aws:SourceArn" = var.sns_topic_arn }
      }
    }]
  })
}

# --- Outputs ---
output "queue_arn" {
  value = aws_sqs_queue.this.arn
}

output "queue_url" {
  value = aws_sqs_queue.this.id
}

output "queue_name" {
  value = aws_sqs_queue.this.name
}

output "dlq_arn" {
  value = aws_sqs_queue.dlq.arn
}

output "dlq_url" {
  value = aws_sqs_queue.dlq.id
}
