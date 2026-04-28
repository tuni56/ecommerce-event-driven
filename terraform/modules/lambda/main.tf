variable "project" {
  description = "Project name prefix"
  type        = string
}

variable "function_name" {
  description = "Lambda function name suffix"
  type        = string
}

variable "handler" {
  description = "Lambda handler"
  type        = string
  default     = "index.handler"
}

variable "runtime" {
  description = "Lambda runtime"
  type        = string
  default     = "nodejs20.x"
}

variable "timeout" {
  description = "Lambda timeout in seconds"
  type        = number
  default     = 10
}

variable "memory_size" {
  description = "Lambda memory in MB"
  type        = number
  default     = 256
}

variable "source_dir" {
  description = "Path to Lambda source directory"
  type        = string
}

variable "environment_variables" {
  description = "Environment variables for the Lambda"
  type        = map(string)
  default     = {}
}

variable "enable_sqs_trigger" {
  description = "Whether to create SQS event source mapping"
  type        = bool
  default     = false
}

variable "sqs_event_source_arn" {
  description = "SQS queue ARN to use as event source"
  type        = string
  default     = ""
}

variable "sqs_batch_size" {
  description = "SQS event source batch size"
  type        = number
  default     = 10
}

variable "additional_policies" {
  description = "Additional IAM policy JSON documents to attach"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}

# --- IAM Role ---
data "aws_iam_policy_document" "assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "this" {
  name               = "${var.project}-${var.function_name}-role"
  assume_role_policy = data.aws_iam_policy_document.assume.json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "basic" {
  role       = aws_iam_role.this.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "sqs" {
  count      = var.enable_sqs_trigger ? 1 : 0
  role       = aws_iam_role.this.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaSQSQueueExecutionRole"
}

resource "aws_iam_role_policy" "additional" {
  count  = length(var.additional_policies)
  name   = "${var.project}-${var.function_name}-policy-${count.index}"
  role   = aws_iam_role.this.id
  policy = var.additional_policies[count.index]
}

# --- Lambda Package ---
data "archive_file" "this" {
  type        = "zip"
  source_dir  = var.source_dir
  output_path = "${path.module}/.build/${var.function_name}.zip"
}

# --- Lambda Function ---
resource "aws_lambda_function" "this" {
  function_name    = "${var.project}-${var.function_name}"
  filename         = data.archive_file.this.output_path
  source_code_hash = data.archive_file.this.output_base64sha256
  handler          = var.handler
  runtime          = var.runtime
  timeout          = var.timeout
  memory_size      = var.memory_size
  role             = aws_iam_role.this.arn
  tags             = var.tags

  environment {
    variables = var.environment_variables
  }
}

# --- SQS Event Source Mapping ---
resource "aws_lambda_event_source_mapping" "sqs" {
  count            = var.enable_sqs_trigger ? 1 : 0
  event_source_arn = var.sqs_event_source_arn
  function_name    = aws_lambda_function.this.arn
  batch_size       = var.sqs_batch_size
}

# --- Outputs ---
output "function_arn" {
  value = aws_lambda_function.this.arn
}

output "function_name" {
  value = aws_lambda_function.this.function_name
}

output "role_arn" {
  value = aws_iam_role.this.arn
}

output "role_name" {
  value = aws_iam_role.this.name
}
