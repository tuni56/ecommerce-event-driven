variable "project" {
  description = "Project name prefix"
  type        = string
}

variable "table_name" {
  description = "DynamoDB table name suffix"
  type        = string
}

variable "hash_key" {
  description = "Hash key attribute name"
  type        = string
}

variable "hash_key_type" {
  description = "Hash key attribute type (S, N, B)"
  type        = string
  default     = "S"
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}

resource "aws_dynamodb_table" "this" {
  name         = "${var.project}-${var.table_name}"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = var.hash_key

  attribute {
    name = var.hash_key
    type = var.hash_key_type
  }

  tags = var.tags
}

output "table_arn" {
  value = aws_dynamodb_table.this.arn
}

output "table_name" {
  value = aws_dynamodb_table.this.name
}
