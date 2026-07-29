output "state_bucket_name" {
  description = "Bucket S3 a usar como 'bucket' en terraform/backend.hcl."
  value       = aws_s3_bucket.state.bucket
}

output "lock_table_name" {
  description = "Tabla DynamoDB a usar como 'dynamodb_table' en terraform/backend.hcl."
  value       = aws_dynamodb_table.locks.name
}

output "aws_region" {
  description = "Región a usar como 'region' en terraform/backend.hcl."
  value       = var.aws_region
}
