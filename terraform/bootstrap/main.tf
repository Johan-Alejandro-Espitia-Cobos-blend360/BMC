# Bootstrap del backend remoto de Terraform: bucket S3 (versionado, cifrado)
# para el state + tabla DynamoDB para locking. Se aplica UNA sola vez, antes
# que terraform/ pueda usar el backend "s3". Este módulo usa state local.
