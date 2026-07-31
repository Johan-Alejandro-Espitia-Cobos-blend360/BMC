# Lambda que conecta el bucket de buzon (s3_inbox.tf) con el endpoint del
# flujo Langflow ya existente. No forma parte del CFN original: es la pieza
# que activa automaticamente todo el pipeline (Textract -> Bedrock) cuando
# el cliente sube un documento a S3, en vez de requerir que llame el
# endpoint /api/v1/run/<FLOW_ID> manualmente.

data "archive_file" "s3_trigger" {
  type        = "zip"
  source_file = "${path.module}/lambda/handler.py"
  output_path = "${path.module}/lambda/handler.zip"
}

data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "s3_trigger" {
  name_prefix        = "${var.stack_name}-s3-trigger-"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

resource "aws_iam_role_policy_attachment" "s3_trigger_basic_execution" {
  role       = aws_iam_role.s3_trigger.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

data "aws_iam_policy_document" "s3_trigger_permissions" {
  statement {
    sid       = "ReadInboxObjects"
    effect    = "Allow"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.documents_inbox.arn}/inbox/*"]
  }

  statement {
    sid       = "WriteResultObjects"
    effect    = "Allow"
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.documents_inbox.arn}/results/*"]
  }

  statement {
    sid       = "ReadLangflowApiKey"
    effect    = "Allow"
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [aws_secretsmanager_secret.s3_trigger_api_key.arn]
  }
}

resource "aws_iam_role_policy" "s3_trigger_permissions" {
  name_prefix = "s3-trigger-permissions-"
  role        = aws_iam_role.s3_trigger.id
  policy      = data.aws_iam_policy_document.s3_trigger_permissions.json
}

resource "aws_lambda_function" "s3_trigger" {
  function_name = "${var.stack_name}-s3-trigger"
  role          = aws_iam_role.s3_trigger.arn
  handler       = "handler.handler"
  runtime       = "python3.12"
  timeout       = 280
  memory_size   = 256

  filename         = data.archive_file.s3_trigger.output_path
  source_code_hash = data.archive_file.s3_trigger.output_base64sha256

  environment {
    variables = {
      LANGFLOW_URL       = "http://${aws_lb.this.dns_name}"
      FLOW_ID            = var.langflow_flow_id
      API_KEY_SECRET_ARN = aws_secretsmanager_secret.s3_trigger_api_key.arn
      RESULTS_PREFIX     = "results/"
    }
  }
}

resource "aws_lambda_permission" "allow_s3_invoke" {
  statement_id  = "AllowExecutionFromS3"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.s3_trigger.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.documents_inbox.arn
}

resource "aws_cloudwatch_log_group" "s3_trigger" {
  name              = "/aws/lambda/${aws_lambda_function.s3_trigger.function_name}"
  retention_in_days = 7
}
