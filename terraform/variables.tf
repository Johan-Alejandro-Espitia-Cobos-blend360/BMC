# Variables de entrada. Equivalentes a los Parameters de
# cloudformation/ecr.yaml y cloudformation/langflow-ecs.yaml, más
# "aws_region" y "stack_name" que en CloudFormation son implícitos
# (AWS::Region / AWS::StackName).

variable "aws_region" {
  type        = string
  description = "Región AWS de despliegue."
  default     = "us-east-1"
}

variable "stack_name" {
  type        = string
  description = <<-EOT
    Prefijo usado para nombrar recursos (VPC, cluster, log group, task
    family, tags Name...), equivalente a AWS::StackName en los templates
    CloudFormation originales (nombre de stack por defecto: langflow-ecs).
  EOT
  default     = "langflow-ecs"
}

# --- cloudformation/ecr.yaml -------------------------------------------------

variable "ecr_repository_name" {
  type        = string
  description = "Nombre del repositorio ECR donde se publica la imagen de Langflow."
  default     = "langflow-idp"

  validation {
    condition     = can(regex("^[a-z0-9]+(?:[._/-][a-z0-9]+)*$", var.ecr_repository_name))
    error_message = "Nombre de repositorio ECR inválido (minúsculas, números, '.', '_', '-', '/')."
  }
}

# --- cloudformation/langflow-ecs.yaml ----------------------------------------

variable "image_uri" {
  type        = string
  description = <<-EOT
    URI completa de la imagen de Langflow en ECR (ej:
    <account>.dkr.ecr.<region>.amazonaws.com/langflow-idp:latest).
  EOT
}

variable "bucket_name" {
  type        = string
  description = "Nombre del bucket S3 temporal de Textract (globalmente único)."
  default     = "langflow-tmp-s3"

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$", var.bucket_name))
    error_message = "Nombre de bucket S3 inválido (3-63 caracteres)."
  }
}

variable "retention_days" {
  type        = number
  description = "Días tras los cuales se eliminan los objetos temporales del bucket."
  default     = 7

  validation {
    condition     = var.retention_days >= 1 && var.retention_days <= 365
    error_message = "retention_days debe estar entre 1 y 365."
  }
}

variable "bedrock_model_id" {
  type        = string
  description = "Id del foundation model de Bedrock que la task role puede invocar."
  default     = "anthropic.claude-3-sonnet-20240229-v1:0"
}

variable "task_cpu" {
  type        = number
  description = "Unidades de CPU de la tarea Fargate."
  default     = 1024

  validation {
    condition     = contains([256, 512, 1024, 2048, 4096], var.task_cpu)
    error_message = "task_cpu debe ser uno de: 256, 512, 1024, 2048, 4096."
  }
}

variable "task_memory_mib" {
  type        = number
  description = "Memoria (MiB) de la tarea Fargate. Debe ser compatible con task_cpu."
  default     = 2048
}

variable "cpu_architecture" {
  type        = string
  description = <<-EOT
    Arquitectura de CPU de la tarea Fargate. Debe coincidir con la
    arquitectura con la que se construyó la imagen (docker build --platform).
  EOT
  default     = "X86_64"

  validation {
    condition     = contains(["X86_64", "ARM64"], var.cpu_architecture)
    error_message = "cpu_architecture debe ser X86_64 o ARM64."
  }
}

variable "db_instance_class" {
  type        = string
  description = "Clase de instancia RDS para la base de datos de Langflow."
  default     = "db.t3.micro"
}

variable "superuser" {
  type        = string
  description = "Login del superusuario de Langflow (la contraseña se autogenera)."
  default     = "admin@example.com"
}

variable "vpc_cidr" {
  type        = string
  description = "Bloque CIDR de la VPC."
  default     = "10.0.0.0/16"
}
