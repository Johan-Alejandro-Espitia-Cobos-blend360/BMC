# TaskRole (Textract, Bedrock InvokeModel de un solo FM, S3 del bucket
# Textract) y ExecutionRole (AmazonECSTaskExecutionRolePolicy + lectura de
# los secretos de BD y superusuario). Equivalente a TaskRole/ExecutionRole en
# cloudformation/langflow-ecs.yaml.

locals {
  # "us.anthropic.claude-sonnet-4-5-20250929-v1:0" -> "anthropic.claude-sonnet-4-5-20250929-v1:0"
  bedrock_inference_underlying_model_id = trimprefix(var.bedrock_inference_profile_id, "us.")
}

data "aws_iam_policy_document" "ecs_tasks_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "task" {
  name_prefix        = "${var.stack_name}-task-"
  description        = "Rol de minimo privilegio de la tarea Langflow (Textract, Bedrock, S3)."
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume_role.json
}

data "aws_iam_policy_document" "task_permissions" {
  statement {
    sid    = "TextractAccess"
    effect = "Allow"
    actions = [
      "textract:DetectDocumentText",
      "textract:StartDocumentTextDetection",
      "textract:GetDocumentTextDetection",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "BedrockInvokeClaude3Sonnet"
    effect = "Allow"
    actions = [
      "bedrock:InvokeModel",
      "bedrock:InvokeModelWithResponseStream",
    ]
    resources = [
      "arn:${data.aws_partition.current.partition}:bedrock:${var.aws_region}::foundation-model/${var.bedrock_model_id}"
    ]
  }

  # GAP PREEXISTENTE (no introducido por la conversión a Terraform): el
  # componente Amazon Bedrock del flujo importado (flow/BMC-aws.json) invoca
  # el inference profile cross-region "us.anthropic.claude-sonnet-4-5-*",
  # distinto al modelo que autoriza BedrockInvokeClaude3Sonnet arriba (que sí
  # replica fielmente el parámetro BedrockModelId del CFN original). Sin este
  # statement adicional, el flujo falla con AccessDeniedException al llegar a
  # Bedrock. Se agrega sin modificar el statement original.
  statement {
    sid    = "BedrockInvokeInferenceProfile"
    effect = "Allow"
    actions = [
      "bedrock:InvokeModel",
      "bedrock:InvokeModelWithResponseStream",
    ]
    resources = [
      # El profile en sí.
      "arn:${data.aws_partition.current.partition}:bedrock:${var.aws_region}:${data.aws_caller_identity.current.account_id}:inference-profile/${var.bedrock_inference_profile_id}",
      # Los modelos regionales subyacentes a los que el profile enruta
      # (requisito de Bedrock para inference profiles cross-region).
      "arn:${data.aws_partition.current.partition}:bedrock:*::foundation-model/${local.bedrock_inference_underlying_model_id}",
    ]
  }

  statement {
    sid    = "TextractBucketObjects"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
    ]
    resources = ["${aws_s3_bucket.textract.arn}/*"]
  }

  statement {
    sid       = "TextractBucketList"
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.textract.arn]
  }
}

resource "aws_iam_role_policy" "task_permissions" {
  name_prefix = "langflow-task-permissions-"
  role        = aws_iam_role.task.id
  policy      = data.aws_iam_policy_document.task_permissions.json
}

resource "aws_iam_role" "execution" {
  name_prefix        = "${var.stack_name}-exec-"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume_role.json
}

resource "aws_iam_role_policy_attachment" "execution_managed" {
  role       = aws_iam_role.execution.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

data "aws_iam_policy_document" "read_langflow_secrets" {
  statement {
    effect  = "Allow"
    actions = ["secretsmanager:GetSecretValue"]
    resources = [
      aws_secretsmanager_secret.langflow_db_url.arn,
      aws_secretsmanager_secret.superuser.arn,
    ]
  }
}

resource "aws_iam_role_policy" "read_langflow_secrets" {
  name_prefix = "read-langflow-secrets-"
  role        = aws_iam_role.execution.id
  policy      = data.aws_iam_policy_document.read_langflow_secrets.json
}
