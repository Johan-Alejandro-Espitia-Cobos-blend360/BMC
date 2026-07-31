# Cluster ECS, Log Group, Task Definition (Fargate) y Service. Equivalente a
# Cluster/LogGroup/TaskDefinition/Service en cloudformation/langflow-ecs.yaml.

resource "aws_ecs_cluster" "this" {
  name = "${var.stack_name}-cluster"
}

resource "aws_cloudwatch_log_group" "langflow" {
  name              = "/ecs/${var.stack_name}/langflow"
  retention_in_days = 7
}

resource "aws_ecs_task_definition" "langflow" {
  family                   = "${var.stack_name}-langflow"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = tostring(var.task_cpu)
  memory                   = tostring(var.task_memory_mib)

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = var.cpu_architecture
  }

  task_role_arn      = aws_iam_role.task.arn
  execution_role_arn = aws_iam_role.execution.arn

  container_definitions = jsonencode([
    {
      name      = "langflow"
      image     = var.image_uri
      essential = true

      portMappings = [
        {
          containerPort = 7860
          protocol      = "tcp"
        }
      ]

      environment = [
        { name = "LANGFLOW_HOST", value = "0.0.0.0" },
        { name = "LANGFLOW_PORT", value = "7860" },
        { name = "LANGFLOW_AUTO_LOGIN", value = "false" },
        { name = "LANGFLOW_SUPERUSER", value = var.superuser },
        { name = "TEXTRACT_BUCKET", value = var.bucket_name },
        { name = "AWS_REGION", value = var.aws_region },
        { name = "CLIENT_MAX_BODY_SIZE", value = "100M" },
        # No forma parte del template CloudFormation original. El código del
        # componente Amazon Bedrock embebido en el flujo importado
        # (flow/BMC-aws.json) ignora el campo "Model ID" del propio nodo y
        # siempre lee el modelo a invocar desde esta variable de entorno
        # (con un default hardcodeado si no está definida). Se agrega para
        # controlar el modelo desde infraestructura, sin tocar el código del
        # componente.
        { name = "BEDROCK_MODEL_ID", value = var.bedrock_inference_profile_id },
      ]

      secrets = [
        { name = "LANGFLOW_DATABASE_URL", valueFrom = aws_secretsmanager_secret.langflow_db_url.arn },
        { name = "LANGFLOW_SUPERUSER_PASSWORD", valueFrom = aws_secretsmanager_secret.superuser.arn },
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.langflow.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "langflow"
        }
      }
    }
  ])
}

resource "aws_ecs_service" "langflow" {
  name                              = "${var.stack_name}-langflow"
  cluster                           = aws_ecs_cluster.this.id
  launch_type                       = "FARGATE"
  desired_count                     = 1
  task_definition                   = aws_ecs_task_definition.langflow.arn
  health_check_grace_period_seconds = 120

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = 50

  network_configuration {
    assign_public_ip = false
    security_groups  = [aws_security_group.service.id]
    subnets = [
      aws_subnet.private_1.id,
      aws_subnet.private_2.id,
    ]
  }

  load_balancer {
    container_name   = "langflow"
    container_port   = 7860
    target_group_arn = aws_lb_target_group.langflow.arn
  }

  depends_on = [aws_lb_listener.langflow]
}
