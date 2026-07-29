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
