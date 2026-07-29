# Backend remoto (S3 + DynamoDB lock), configuración parcial: los valores
# concretos (bucket, tabla, región) se pasan en el init para no hardcodear
# nombres específicos del entorno en el código versionado.
#
#   terraform init -backend-config=backend.hcl
#
# Ver backend.hcl.example. bucket/dynamodb_table deben coincidir con los
# outputs de terraform/bootstrap una vez aplicado.

terraform {
  backend "s3" {}
}
