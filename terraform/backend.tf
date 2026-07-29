# Backend remoto (S3 + DynamoDB lock). El bucket y la tabla se crean una sola
# vez desde bootstrap/. Los valores de bucket/key/region/dynamodb_table se
# completan cuando bootstrap/ esté aplicado.
#
# terraform {
#   backend "s3" {
#     bucket         = ""
#     key            = "bmc/terraform.tfstate"
#     region         = ""
#     dynamodb_table = ""
#     encrypt        = true
#   }
# }
