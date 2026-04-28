locals {
  prefix = "${var.project}-${var.environment}"
  tags   = { Environment = var.environment }

  lambda_base_path = "${path.module}/../../../lambdas"
}

# ============================================================
# SNS — Single entry point for all order events
# ============================================================
module "sns_orders" {
  source  = "../../modules/sns"
  project = local.prefix
  name    = "orders"
  tags    = local.tags
}

# ============================================================
# SQS — One queue per consumer, each with its own DLQ
# ============================================================
module "sqs_order_processing" {
  source             = "../../modules/sqs"
  project            = local.prefix
  name               = "order-processing"
  subscribe_to_sns   = true
  sns_topic_arn      = module.sns_orders.topic_arn
  visibility_timeout = 60
  tags               = local.tags
}

module "sqs_inventory" {
  source             = "../../modules/sqs"
  project            = local.prefix
  name               = "inventory-update"
  subscribe_to_sns   = true
  sns_topic_arn      = module.sns_orders.topic_arn
  visibility_timeout = 60
  tags               = local.tags
}

module "sqs_analytics" {
  source             = "../../modules/sqs"
  project            = local.prefix
  name               = "analytics-ingestion"
  subscribe_to_sns   = true
  sns_topic_arn      = module.sns_orders.topic_arn
  visibility_timeout = 60
  tags               = local.tags
}

# ============================================================
# DynamoDB — Real-time path storage
# ============================================================
module "dynamodb_orders" {
  source     = "../../modules/dynamodb"
  project    = local.prefix
  table_name = "orders"
  hash_key   = "orderId"
  tags       = local.tags
}

module "dynamodb_inventory" {
  source     = "../../modules/dynamodb"
  project    = local.prefix
  table_name = "inventory"
  hash_key   = "productId"
  tags       = local.tags
}

# ============================================================
# S3 — Batch path landing zone
# ============================================================
module "s3_analytics" {
  source      = "../../modules/s3"
  project     = local.prefix
  bucket_name = "analytics-landing"
  tags        = local.tags
}

# ============================================================
# Lambda — Event consumers
# ============================================================
data "aws_iam_policy_document" "dynamodb_orders" {
  statement {
    actions   = ["dynamodb:PutItem", "dynamodb:GetItem", "dynamodb:UpdateItem"]
    resources = [module.dynamodb_orders.table_arn]
  }
}

data "aws_iam_policy_document" "dynamodb_inventory" {
  statement {
    actions   = ["dynamodb:PutItem", "dynamodb:GetItem", "dynamodb:UpdateItem"]
    resources = [module.dynamodb_inventory.table_arn]
  }
}

data "aws_iam_policy_document" "s3_analytics" {
  statement {
    actions   = ["s3:PutObject"]
    resources = ["${module.s3_analytics.bucket_arn}/*"]
  }
}

module "lambda_order_processor" {
  source               = "../../modules/lambda"
  project              = local.prefix
  function_name        = "order-processor"
  source_dir           = "${local.lambda_base_path}/order-processor/src"
  enable_sqs_trigger   = true
  sqs_event_source_arn = module.sqs_order_processing.queue_arn
  timeout              = 10
  tags                 = local.tags

  environment_variables = {
    ORDERS_TABLE = module.dynamodb_orders.table_name
  }

  additional_policies = [data.aws_iam_policy_document.dynamodb_orders.json]
}

module "lambda_inventory_updater" {
  source               = "../../modules/lambda"
  project              = local.prefix
  function_name        = "inventory-updater"
  source_dir           = "${local.lambda_base_path}/inventory-updater/src"
  enable_sqs_trigger   = true
  sqs_event_source_arn = module.sqs_inventory.queue_arn
  timeout              = 10
  tags                 = local.tags

  environment_variables = {
    INVENTORY_TABLE = module.dynamodb_inventory.table_name
  }

  additional_policies = [data.aws_iam_policy_document.dynamodb_inventory.json]
}

module "lambda_analytics_ingester" {
  source               = "../../modules/lambda"
  project              = local.prefix
  function_name        = "analytics-ingester"
  source_dir           = "${local.lambda_base_path}/analytics-ingester/src"
  enable_sqs_trigger   = true
  sqs_event_source_arn = module.sqs_analytics.queue_arn
  timeout              = 10
  tags                 = local.tags

  environment_variables = {
    ANALYTICS_BUCKET = module.s3_analytics.bucket_name
  }

  additional_policies = [data.aws_iam_policy_document.s3_analytics.json]
}

# ============================================================
# SNS — Alarm notifications
# ============================================================
module "sns_alarms" {
  source  = "../../modules/sns"
  project = local.prefix
  name    = "alarms"
  tags    = local.tags
}

resource "aws_sns_topic_subscription" "alarm_email" {
  topic_arn = module.sns_alarms.topic_arn
  protocol  = "email"
  endpoint  = var.alarm_email
}

# ============================================================
# Monitoring — DLQ alarms + Dashboard
# ============================================================
module "monitoring" {
  source              = "../../modules/monitoring"
  project             = local.prefix
  sns_alarm_topic_arn = module.sns_alarms.topic_arn
  tags                = local.tags

  dlq_alarms = {
    "${local.prefix}-order-processing-dlq"    = module.sqs_order_processing.dlq_arn
    "${local.prefix}-inventory-update-dlq"    = module.sqs_inventory.dlq_arn
    "${local.prefix}-analytics-ingestion-dlq" = module.sqs_analytics.dlq_arn
  }

  lambda_function_names = [
    module.lambda_order_processor.function_name,
    module.lambda_inventory_updater.function_name,
    module.lambda_analytics_ingester.function_name,
  ]

  sqs_queue_names = [
    module.sqs_order_processing.queue_name,
    module.sqs_inventory.queue_name,
    module.sqs_analytics.queue_name,
  ]
}

# ============================================================
# Outputs
# ============================================================
output "sns_topic_arn" {
  value = module.sns_orders.topic_arn
}

output "order_processing_queue_url" {
  value = module.sqs_order_processing.queue_url
}

output "analytics_bucket" {
  value = module.s3_analytics.bucket_name
}
