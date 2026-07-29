# Bucket S3 temporal de Textract: cifrado SSE-S3, bloqueo público total,
# lifecycle de expiración por retention_days. Equivalente a TextractBucket en
# cloudformation/langflow-ecs.yaml (DeletionPolicy/UpdateReplacePolicy: Delete
# -> comportamiento por defecto de Terraform al destruir, sin force_destroy).

resource "aws_s3_bucket" "textract" {
  bucket = var.bucket_name
}

resource "aws_s3_bucket_server_side_encryption_configuration" "textract" {
  bucket = aws_s3_bucket.textract.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "textract" {
  bucket = aws_s3_bucket.textract.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "textract" {
  bucket = aws_s3_bucket.textract.id

  rule {
    id     = "ExpireTextractTempObjects"
    status = "Enabled"

    filter {}

    expiration {
      days = var.retention_days
    }
  }
}
