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

variable "lambda_function_names" {
  description = "List of Lambda function names for dashboard metrics"
  type        = list(string)
  default     = []
}

variable "sqs_queue_names" {
  description = "List of SQS queue names for dashboard metrics"
  type        = list(string)
  default     = []
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
  ok_actions    = var.sns_alarm_topic_arn != null ? [var.sns_alarm_topic_arn] : []
  tags          = var.tags
}

# --- Observability Dashboard ---
resource "aws_cloudwatch_dashboard" "main" {
  count          = length(var.lambda_function_names) > 0 ? 1 : 0
  dashboard_name = "${var.project}-platform"

  dashboard_body = jsonencode({
    widgets = concat(
      # Lambda metrics row
      [
        {
          type   = "text"
          x      = 0
          y      = 0
          width  = 24
          height = 1
          properties = {
            markdown = "# 🔧 Lambda Functions"
          }
        },
        {
          type   = "metric"
          x      = 0
          y      = 1
          width  = 8
          height = 6
          properties = {
            title   = "Lambda Invocations"
            region  = data.aws_region.current.name
            metrics = [for fn in var.lambda_function_names : ["AWS/Lambda", "Invocations", "FunctionName", fn]]
            period  = 60
            stat    = "Sum"
            view    = "timeSeries"
          }
        },
        {
          type   = "metric"
          x      = 8
          y      = 1
          width  = 8
          height = 6
          properties = {
            title   = "Lambda Errors"
            region  = data.aws_region.current.name
            metrics = [for fn in var.lambda_function_names : ["AWS/Lambda", "Errors", "FunctionName", fn]]
            period  = 60
            stat    = "Sum"
            view    = "timeSeries"
          }
        },
        {
          type   = "metric"
          x      = 16
          y      = 1
          width  = 8
          height = 6
          properties = {
            title   = "Lambda Duration (avg ms)"
            region  = data.aws_region.current.name
            metrics = [for fn in var.lambda_function_names : ["AWS/Lambda", "Duration", "FunctionName", fn]]
            period  = 60
            stat    = "Average"
            view    = "timeSeries"
          }
        }
      ],
      # SQS metrics row
      [
        {
          type   = "text"
          x      = 0
          y      = 7
          width  = 24
          height = 1
          properties = {
            markdown = "# 📬 SQS Queues"
          }
        },
        {
          type   = "metric"
          x      = 0
          y      = 8
          width  = 12
          height = 6
          properties = {
            title   = "Messages In Queue"
            region  = data.aws_region.current.name
            metrics = [for q in var.sqs_queue_names : ["AWS/SQS", "ApproximateNumberOfMessagesVisible", "QueueName", q]]
            period  = 60
            stat    = "Sum"
            view    = "timeSeries"
          }
        },
        {
          type   = "metric"
          x      = 12
          y      = 8
          width  = 12
          height = 6
          properties = {
            title   = "DLQ Messages (⚠️ should be 0)"
            region  = data.aws_region.current.name
            metrics = [for name, _ in var.dlq_alarms : ["AWS/SQS", "ApproximateNumberOfMessagesVisible", "QueueName", name]]
            period  = 60
            stat    = "Sum"
            view    = "timeSeries"
          }
        }
      ]
    )
  })
}

data "aws_region" "current" {}
