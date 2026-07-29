# DB Subnet Group + instancia RDS PostgreSQL 16.6 privada. Equivalente a
# DbSubnetGroup/Database en cloudformation/langflow-ecs.yaml (DeletionPolicy/
# UpdateReplacePolicy: Delete -> skip_final_snapshot = true, sin snapshot
# final, igual que hace CFN).

resource "aws_db_subnet_group" "this" {
  description = "Subredes privadas para RDS de Langflow."
  subnet_ids = [
    aws_subnet.private_1.id,
    aws_subnet.private_2.id,
  ]
}

resource "aws_db_instance" "this" {
  engine         = "postgres"
  engine_version = "16.6"
  instance_class = var.db_instance_class

  db_name  = "langflow"
  username = "langflow"
  password = random_password.db.result

  allocated_storage       = 20
  max_allocated_storage   = 50
  multi_az                = false
  publicly_accessible     = false
  storage_encrypted       = true
  backup_retention_period = 1

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.db.id]

  skip_final_snapshot = true
}
