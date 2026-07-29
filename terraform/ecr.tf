# Equivalente a cloudformation/ecr.yaml: repositorio ECR de la imagen
# Langflow + política de ciclo de vida (conservar las últimas 10 imágenes).

resource "aws_ecr_repository" "langflow" {
  name                 = var.ecr_repository_name
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_lifecycle_policy" "langflow" {
  repository = aws_ecr_repository.langflow.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Conservar solo las ultimas 10 imagenes"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 10
        }
        action = { type = "expire" }
      }
    ]
  })
}
