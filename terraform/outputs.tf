# Outputs, equivalentes a los Outputs de cloudformation/ecr.yaml y
# cloudformation/langflow-ecs.yaml.

# --- ecr.yaml -----------------------------------------------------------

output "ecr_repository_uri" {
  description = "URI del repositorio ECR. Usar como base de IMAGE_URI (<uri>:<tag>)."
  value       = aws_ecr_repository.langflow.repository_url
}

output "ecr_repository_name" {
  description = "Nombre del repositorio ECR."
  value       = aws_ecr_repository.langflow.name
}

# --- langflow-ecs.yaml ----------------------------------------------------

output "langflow_url" {
  description = <<-EOT
    URL base del servicio Langflow (ALB). Usar como LANGFLOW_URL para
    flow/import_flow.sh; el endpoint de ejecución es <esta>/api/v1/run/<FLOW_ID>.
  EOT
  value       = "http://${aws_lb.this.dns_name}"
}

output "textract_bucket_name" {
  description = "Bucket de Textract que la task role puede leer/escribir."
  value       = aws_s3_bucket.textract.bucket
}

output "aws_region" {
  description = "Región AWS del despliegue."
  value       = var.aws_region
}

output "langflow_superuser_name" {
  description = "Login del superusuario; el password está en el secreto superuser."
  value       = var.superuser
}

output "superuser_password_secret_arn" {
  description = "ARN del secreto con el password del superusuario de Langflow."
  value       = aws_secretsmanager_secret.superuser.arn
}

output "db_url_secret_arn" {
  description = "ARN del secreto con LANGFLOW_DATABASE_URL."
  value       = aws_secretsmanager_secret.langflow_db_url.arn
}

# --- Carga de documentos por evento S3 (no forma parte del CFN original) ---

output "documents_inbox_bucket_name" {
  description = "Bucket donde subir documentos (prefijo inbox/) y consultar resultados (prefijo results/)."
  value       = aws_s3_bucket.documents_inbox.bucket
}

output "s3_trigger_lambda_name" {
  description = "Nombre de la Lambda que conecta el bucket de buzón con el flujo Langflow."
  value       = aws_lambda_function.s3_trigger.function_name
}

output "s3_trigger_api_key_secret_arn" {
  description = "ARN del secreto donde debe cargarse la API key de Langflow para la Lambda (put-secret-value manual, ver README)."
  value       = aws_secretsmanager_secret.s3_trigger_api_key.arn
}
