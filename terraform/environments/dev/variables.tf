variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-2"
}

variable "project" {
  description = "Project name"
  type        = string
  default     = "ecommerce-ed"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}
