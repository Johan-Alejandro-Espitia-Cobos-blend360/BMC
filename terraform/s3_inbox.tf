# Bucket de "buzon" para carga de documentos por evento (Opcion B). No forma
# parte del template CloudFormation original: es una capacidad nueva,
# solicitada explicitamente, que dispara el flujo ya existente sin exponer
# el endpoint de Langflow al llamador. Convive con aws_s3_bucket.textract
# (s3.tf), que sigue siendo exclusivamente el buffer interno de Textract
# para PDFs escaneados.
#
# Prefijos dentro del mismo bucket:
#   inbox/    -> el cliente sube aqui el documento original (dispara la Lambda)
#   results/  -> la Lambda escribe aqui la respuesta de Langflow (o el error)

resource "aws_s3_bucket" "documents_inbox" {
  bucket = "${var.stack_name}-documents-inbox-${data.aws_caller_identity.current.account_id}"
}

resource "aws_s3_bucket_server_side_encryption_configuration" "documents_inbox" {
  bucket = aws_s3_bucket.documents_inbox.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "documents_inbox" {
  bucket = aws_s3_bucket.documents_inbox.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "documents_inbox" {
  bucket = aws_s3_bucket.documents_inbox.id

  rule {
    id     = "ExpireInboxObjects"
    status = "Enabled"

    filter { prefix = "inbox/" }

    expiration {
      days = var.retention_days
    }
  }

  rule {
    id     = "ExpireResultObjects"
    status = "Enabled"

    filter { prefix = "results/" }

    expiration {
      days = var.retention_days
    }
  }
}

resource "aws_s3_bucket_notification" "documents_inbox" {
  bucket = aws_s3_bucket.documents_inbox.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.s3_trigger.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "inbox/"
  }

  depends_on = [aws_lambda_permission.allow_s3_invoke]
}
