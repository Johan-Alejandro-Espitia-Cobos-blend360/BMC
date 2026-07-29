variable "aws_region" {
  type        = string
  description = "Región AWS donde se crean el bucket de state y la tabla de lock."
  default     = "us-east-1"
}

variable "state_bucket_name" {
  type        = string
  description = "Nombre del bucket S3 para el remote state (globalmente único)."
}

variable "lock_table_name" {
  type        = string
  description = "Nombre de la tabla DynamoDB usada para locking del state."
  default     = "bmc-terraform-locks"
}
