# Security Groups: ALB (80 público), servicio Fargate (7860 desde ALB),
# RDS (5432 desde el servicio). Equivalente a los *SecurityGroup* de
# cloudformation/langflow-ecs.yaml.
#
# CloudFormation, al no declarar SecurityGroupEgress, conserva la regla de
# egreso "todo permitido" que EC2 crea por defecto en cada SG nuevo. Para
# mantener el mismo comportamiento se declara explícitamente ese egress en
# cada grupo (Terraform, a diferencia de CFN, sí elimina el egress por
# defecto si no se declara).

resource "aws_security_group" "alb" {
  name_prefix = "${var.stack_name}-alb-sg-"
  description = "ALB publico de Langflow (HTTP 80 entrante)."
  vpc_id      = aws_vpc.this.id

  ingress {
    description = "HTTP publico"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.stack_name}-alb-sg"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group" "service" {
  name_prefix = "${var.stack_name}-svc-sg-"
  description = "Tareas Fargate de Langflow (7860 desde el ALB)."
  vpc_id      = aws_vpc.this.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.stack_name}-svc-sg"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "service_ingress_from_alb" {
  type                     = "ingress"
  security_group_id        = aws_security_group.service.id
  from_port                = 7860
  to_port                  = 7860
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.alb.id
  description              = "ALB hacia el contenedor Langflow"
}

resource "aws_security_group" "db" {
  name_prefix = "${var.stack_name}-db-sg-"
  description = "RDS PostgreSQL de Langflow (5432 desde el servicio)."
  vpc_id      = aws_vpc.this.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.stack_name}-db-sg"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "db_ingress_from_service" {
  type                     = "ingress"
  security_group_id        = aws_security_group.db.id
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.service.id
  description              = "Servicio Fargate hacia RDS PostgreSQL"
}
