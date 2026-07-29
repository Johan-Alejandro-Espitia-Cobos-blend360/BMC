# DB Subnet Group + instancia RDS PostgreSQL privada. Equivalente a
# DbSubnetGroup/Database en cloudformation/langflow-ecs.yaml (DeletionPolicy/
# UpdateReplacePolicy: Delete -> skip_final_snapshot = true, sin snapshot
# final, igual que hace CFN).
#
# DESVIACIÓN NECESARIA: el template CFN original fija EngineVersion "16.6",
# pero esa versión fue retirada del catálogo de AWS (ya no es instanciable en
# ninguna cuenta). Se usa "16.9" -- la versión 16.x disponible más cercana por
# encima de 16.6 -- para preservar la intención original (misma línea major,
# con los parches que 16.6 ya habría incluido).

resource "aws_db_subnet_group" "this" {
  description = "Subredes privadas para RDS de Langflow."
  subnet_ids = [
    aws_subnet.private_1.id,
    aws_subnet.private_2.id,
  ]
}

resource "aws_db_instance" "this" {
  engine         = "postgres"
  engine_version = "16.9"
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
