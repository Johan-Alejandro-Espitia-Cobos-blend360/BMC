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
├── providers.tf                # provider aws + archive
├── variables.tf                # parámetros (equivalentes a los Parameters de CFN)
├── outputs.tf                  # outputs (equivalentes a los Outputs de CFN)
├── ecr.tf                      # repositorio ECR (≈ cloudformation/ecr.yaml)
├── network.tf                  # VPC, subredes, IGW, NAT, route tables
├── security_groups.tf          # SGs de ALB, servicio y RDS
├── s3.tf                       # bucket temporal de Textract (interno, PDFs escaneados)
├── s3_inbox.tf                 # bucket de carga de documentos por evento (inbox/ + results/)
├── lambda.tf                   # Lambda que conecta el bucket de carga con el flujo Langflow
├── lambda/handler.py           # código de esa Lambda
├── iam.tf                      # TaskRole y ExecutionRole
├── secrets.tf                  # Secrets Manager (credenciales BD, superusuario, API key de la Lambda)
├── rds.tf                      # RDS PostgreSQL
├── ecs.tf                      # Cluster, Task Definition y Service (Fargate)
├── alb.tf                      # Application Load Balancer
└── terraform.tfvars.example    # valores de ejemplo (≈ parameters.example.json)
```

Cada archivo `.tf` referencia en un comentario el recurso CloudFormation que
reemplaza, como guía de la conversión. `s3_inbox.tf` y `lambda.tf` son la
única excepción: no reemplazan nada del CFN original, son una capacidad
nueva agregada después (ver sección "Carga automática de documentos por S3"
más abajo).

## Estado del proyecto

Desplegado y validado end-to-end (infraestructura + flujo Langflow con
Textract y Bedrock) en una cuenta AWS separada. `terraform plan` no reporta
drift contra el estado real.

## Prerrequisitos (antes de `terraform apply`)

1. **Habilitar el acceso al modelo de Bedrock en la cuenta** (paso manual,
   una sola vez por cuenta AWS — Terraform no puede automatizarlo):
   Consola → **Amazon Bedrock** → **Model access** → **Enable specific
   models** → selecciona el modelo Anthropic que use `bedrock_inference_profile_id`
   (por defecto Claude Haiku 4.5). La primera vez que se habilita un modelo
   de Anthropic en la cuenta, AWS pide un formulario "First Time Use"
   (nombre de empresa, sitio web, caso de uso) y la aceptación del EULA del
   modelo. **Sin este paso, el ECS task queda arriba y saludable, pero el
   flujo falla con `AccessDeniedException` al invocar Bedrock** (por
   agreement de AWS Marketplace, no por permisos IAM).
2. Credenciales AWS válidas para la cuenta destino (`aws login` o el método
   que uses) con permisos para crear todos los recursos de este stack.
3. Docker y AWS CLI instalados localmente para construir y publicar la
   imagen (paso 2 más abajo).

## Uso

```bash
# 1. Backend remoto (una sola vez)
cd terraform/bootstrap
terraform init
terraform apply -var="state_bucket_name=<nombre-unico-global>"

# 2. Stack principal — se aplica en 3 pasos, igual que los scripts
#    originales (scripts/01-03), porque la imagen debe existir en ECR
#    antes de poder desplegar la Task Definition que la referencia.
cd ../
cp backend.hcl.example backend.hcl   # completar con los outputs del paso 1
terraform init -backend-config=backend.hcl
cp terraform.tfvars.example terraform.tfvars   # completar bucket_name, etc.

# 2a. Crear solo el repositorio ECR
terraform apply -target=aws_ecr_repository.langflow

# 2b. Construir y publicar la imagen (usa --provenance=false --sbom=false
#     para que el escaneo de vulnerabilidades de ECR funcione; de lo
#     contrario Docker BuildKit genera un índice OCI que ECR no escanea)
ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
REGION="us-east-1"
REPO_URI="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/langflow-idp"
aws ecr get-login-password --region "$REGION" | docker login --username AWS --password-stdin "${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"
docker build --provenance=false --sbom=false --platform linux/amd64 \
  -t "${REPO_URI}:latest" ../infra-share/docker
docker push "${REPO_URI}:latest"

# 2c. Desplegar el resto del stack, pasando la imagen ya publicada
terraform apply -var="image_uri=${REPO_URI}:latest"
```

## Después del `apply`

- La contraseña del superusuario de Langflow queda en Secrets Manager (ver
  output `superuser_password_secret_arn`) — nunca se define en texto plano.
- Importa el flujo (`flow/import_flow.sh` del repo `infra-share`) y
  verifícalo con `flow/verify_flow.sh` apuntando a `langflow_url`.
- Copia el `FLOW_ID` impreso por `import_flow.sh` a `terraform.tfvars`
  (`langflow_flow_id`) — lo necesita la Lambda de carga automática (ver
  abajo).
- `terraform plan` sin cambios ("No changes.") confirma que no hay drift
  entre el código y lo desplegado.

## Carga automática de documentos por S3

Capacidad agregada después del despliegue inicial, a solicitud explícita.
**No forma parte del template CloudFormation original** ni modifica nada
del flujo de Langflow o del pipeline Textract/Bedrock ya validado — solo
agrega una vía alterna de entrada, disparada por eventos, en vez de requerir
que el cliente llame directamente al endpoint `/api/v1/run/<FLOW_ID>`.

### Cómo funciona

```
Cliente sube el archivo a S3 (prefijo inbox/)
   │
   ▼
Evento s3:ObjectCreated dispara la Lambda "<stack_name>-s3-trigger"
   │
   ▼
La Lambda descarga el archivo, arma el mismo payload
{media_type, content(base64)} que usa flow/verify_flow.sh, y hace
POST a http://<ALB>/api/v1/run/<FLOW_ID> con una API key propia
   │
   ▼
Se ejecuta el flujo de siempre: Textract -> Bedrock (Haiku 4.5) -> respuesta
   │
   ▼
La Lambda escribe la respuesta en el mismo bucket, prefijo results/
(<nombre-archivo>.ok.json, o .error.json si el flujo devolvió error)
```

### Uso

```bash
# Cargar un documento (dispara todo automáticamente)
aws s3 cp mi-documento.pdf s3://<documents_inbox_bucket_name>/inbox/mi-documento.pdf

# Consultar el resultado (puede tardar unos segundos)
aws s3 cp s3://<documents_inbox_bucket_name>/results/mi-documento.pdf.ok.json .
```

El nombre real del bucket sale del output `documents_inbox_bucket_name`.

### Paso manual pendiente después de cada `apply` inicial: cargar la API key

Terraform crea el secreto `s3_trigger_api_key_secret_arn` **vacío** —
las API keys de Langflow solo se pueden crear desde la propia aplicación
(no hay recurso de Terraform para eso), así que no se puede generar en el
`apply`. Se crea una vez, a mano o por script, así:

```bash
# 1. Login como superusuario y crear una API key nueva para la Lambda
TOKEN=$(curl -sS -X POST "<langflow_url>/api/v1/login" \
  --data-urlencode "username=<superuser>" \
  --data-urlencode "password=<password-desde-Secrets-Manager>" \
  | jq -r .access_token)

API_KEY=$(curl -sS -X POST "<langflow_url>/api/v1/api_key/" \
  -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d '{"name":"s3-trigger-lambda"}' | jq -r .api_key)

# 2. Cargarla en el secreto que la Lambda lee en tiempo de ejecución
aws secretsmanager put-secret-value \
  --secret-id "<s3_trigger_api_key_secret_arn>" \
  --secret-string "$API_KEY"
```

Sin este paso, la Lambda falla al invocar Bedrock/Langflow porque no tiene
`x-api-key` válido (el error queda en CloudWatch Logs, log group
`/aws/lambda/<stack_name>-s3-trigger`, y también en
`results/<archivo>.error.json`).

### Formatos soportados y retención

Mismos formatos que ya soportaba el flujo (texto plano, imagen, PDF digital
o escaneado). Los objetos bajo `inbox/` y `results/` expiran automáticamente
a los `retention_days` (por defecto 7 días) — no es almacenamiento
permanente de resultados; si el cliente necesita conservarlos más tiempo,
debe descargarlos antes de que expiren o ajustar `retention_days`.
