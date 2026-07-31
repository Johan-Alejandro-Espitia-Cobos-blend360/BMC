# Secrets Manager: credenciales RDS autogeneradas, LANGFLOW_DATABASE_URL
# completa y password del superusuario. Equivalente a DbCredentialsSecret /
# SuperuserSecret / LangflowDbUrlSecret en cloudformation/langflow-ecs.yaml.
#
# CloudFormation genera las contraseñas server-side vía GenerateSecretString;
# en Terraform se replica con el provider random, igualando longitud y
# caracteres excluidos para no romper la URL postgresql://.

# Excluye los mismos caracteres que ExcludeCharacters en CFN:
# '/@"\'\\ %:?#[]&+' (barra, arroba, comillas, backslash, espacio, %, :, ?,
# #, [, ], &, +). Los especiales permitidos que quedan: ! $ ^ * ( ) - _ = { } < >
resource "random_password" "db" {
  length           = 32
  override_special = "!$^*()-_={}<>"
}

resource "random_password" "superuser" {
  length  = 24
  special = false # equivalente a ExcludePunctuation: true en CFN
}

resource "aws_secretsmanager_secret" "db_credentials" {
  description = "Credenciales autogeneradas de RDS PostgreSQL para Langflow."
}

resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    username = "langflow"
    password = random_password.db.result
  })
}

resource "aws_secretsmanager_secret" "superuser" {
  description = "Password del superusuario de Langflow."
}

resource "aws_secretsmanager_secret_version" "superuser" {
  secret_id     = aws_secretsmanager_secret.superuser.id
  secret_string = random_password.superuser.result
}

# LANGFLOW_DATABASE_URL completa. El password nunca queda en el código
# versionado: se resuelve en apply, igual que el dynamic reference de CFN.
resource "aws_secretsmanager_secret" "langflow_db_url" {
  description = "LANGFLOW_DATABASE_URL completa para el servicio Langflow."
}

resource "aws_secretsmanager_secret_version" "langflow_db_url" {
  secret_id     = aws_secretsmanager_secret.langflow_db_url.id
  secret_string = "postgresql://langflow:${random_password.db.result}@${aws_db_instance.this.address}:${aws_db_instance.this.port}/langflow"
}

# API key que usa la Lambda de disparo por S3 (lambda.tf) para llamar al
# endpoint del flujo. A diferencia de las credenciales de arriba, Terraform
# NO puede generar este valor: las API keys de Langflow solo se crean desde
# la propia aplicación (API/UI) una vez que el superusuario existe. Se crea
# el secreto vacío aquí; el valor se carga en un paso posterior con
# `aws secretsmanager put-secret-value` (ver README).
resource "aws_secretsmanager_secret" "s3_trigger_api_key" {
  description = "API key de Langflow usada por la Lambda de disparo por S3 (${var.stack_name}-s3-trigger)."
}
