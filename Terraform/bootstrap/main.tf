locals {
  bucket_force_destroy = false
  final_bucket_name     = lower(join("-", compact([var.project_name, "terraform-state"])))
  final_dynamodb_table  = lower(join("-", compact([var.project_name, var.dynamodb_table_name])))
}

data "aws_caller_identity" "current" {}

resource "aws_s3_bucket" "tf_state" {
  bucket        = local.final_bucket_name
  force_destroy = local.bucket_force_destroy
}

resource "aws_s3_bucket_versioning" "tf_state_versioning" {
  bucket = aws_s3_bucket.tf_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tf_state_sse" {
  bucket = aws_s3_bucket.tf_state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_dynamodb_table" "tf_locks" {
  name         = local.final_dynamodb_table
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}

output "backend_bucket" { value = aws_s3_bucket.tf_state.bucket }
output "backend_dynamodb_table" { value = aws_dynamodb_table.tf_locks.name }


