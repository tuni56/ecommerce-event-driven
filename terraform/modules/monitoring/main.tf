# CloudWatch alarms for DLQ monitoring (see ADR-002)
# Any message in a DLQ means something failed — always alert.

variable "project" {
  description = "Project name prefix"
  type        = string
}

variable "dlq_alarms" {
  description = "Map of DLQ names to their ARNs for alarm creation"
  type        = map(string)
}

variable "sns_alarm_topic_arn" {
  description = "SNS topic ARN for alarm notifications"
  type        = string
  default     = null
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}

resource "aws_cloudwatch_metric_alarm" "dlq" {
  for_each = var.dlq_alarms

  alarm_name          = "${var.project}-dlq-${each.key}"
  alarm_description   = "Messages detected in DLQ: ${each.key}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = 60
  statistic           = "Sum"
  threshold           = 0
  treat_missing_data  = "notBreaching"

  dimensions = {
    QueueName = each.key
  }

  alarm_actions = var.sns_alarm_topic_arn != null ? [var.sns_alarm_topic_arn] : []
  tags          = var.tags
}
