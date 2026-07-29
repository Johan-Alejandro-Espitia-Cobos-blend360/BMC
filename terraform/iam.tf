# TaskRole (Textract, Bedrock InvokeModel de un solo FM, S3 del bucket
# Textract) y ExecutionRole (AmazonECSTaskExecutionRolePolicy + lectura de
# los secretos de BD y superusuario). Equivalente a TaskRole/ExecutionRole en
# cloudformation/langflow-ecs.yaml.

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
