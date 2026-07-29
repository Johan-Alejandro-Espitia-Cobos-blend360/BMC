# BMC — Infraestructura como código (Terraform)

Conversión a Terraform de la infraestructura AWS del servicio Langflow IDP
(Bolsa Mercantil de Colombia), manteniendo exactamente los mismos recursos y
comportamiento que el despliegue actual en CloudFormation
(`infra-share/cloudformation/`). Sin cambios de arquitectura ni de buenas
prácticas en esta primera fase — solo conversión 1:1.

## Estructura

```
terraform/
├── bootstrap/                  # backend remoto (S3 + DynamoDB lock); se aplica una sola vez
├── backend.tf                  # config del backend "s3"
├── providers.tf                # provider aws
├── variables.tf                # parámetros (equivalentes a los Parameters de CFN)
├── outputs.tf                  # outputs (equivalentes a los Outputs de CFN)
├── ecr.tf                      # repositorio ECR (≈ cloudformation/ecr.yaml)
├── network.tf                  # VPC, subredes, IGW, NAT, route tables
├── security_groups.tf          # SGs de ALB, servicio y RDS
├── s3.tf                       # bucket temporal de Textract
├── iam.tf                      # TaskRole y ExecutionRole
├── secrets.tf                  # Secrets Manager (credenciales BD, superusuario)
├── rds.tf                      # RDS PostgreSQL
├── ecs.tf                      # Cluster, Task Definition y Service (Fargate)
├── alb.tf                      # Application Load Balancer
└── terraform.tfvars.example    # valores de ejemplo (≈ parameters.example.json)
```

Cada archivo `.tf` referencia en un comentario el recurso CloudFormation que
reemplaza, como guía de la conversión.

## Estado del proyecto

Recursos implementados y validados con `terraform fmt` + `terraform validate`
(sin backend, sin `apply`). Pendiente: aplicar `bootstrap/`, aplicar el stack
principal e importar/cortar desde el stack CloudFormation actual.

## Uso

```bash
# 1. Backend remoto (una sola vez)
cd terraform/bootstrap
terraform init
terraform apply -var="state_bucket_name=<nombre-unico-global>"

# 2. Stack principal
cd ../
cp backend.hcl.example backend.hcl   # completar con los outputs del paso 1
terraform init -backend-config=backend.hcl
cp terraform.tfvars.example terraform.tfvars   # completar ImageUri, BucketName, etc.
terraform plan
terraform apply
```
