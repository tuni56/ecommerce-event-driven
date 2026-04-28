variable "project" {
  description = "Project name prefix for all resources"
  type        = string
}

variable "name" {
  description = "Topic name suffix"
  type        = string
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}

resource "aws_sns_topic" "this" {
  name = "${var.project}-${var.name}"
  tags = var.tags
}

output "topic_arn" {
  value = aws_sns_topic.this.arn
}

output "topic_name" {
  value = aws_sns_topic.this.name
}
