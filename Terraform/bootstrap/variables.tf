variable "region" {
  description = "AWS region to create backend resources"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name prefix for backend resources"
  type        = string
}

variable "dynamodb_table_name" {
  description = "Base name of the DynamoDB table (auto-derived)"
  type        = string
  default     = "terraform-locks"
}


