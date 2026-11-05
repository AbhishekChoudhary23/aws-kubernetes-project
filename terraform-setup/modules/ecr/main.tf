resource "aws_ecr_repository" "repos" {
  for_each = var.repositories

  name                 = "${var.project_name}-${each.key}"
  image_tag_mutability = each.value.image_tag_mutability
  force_delete         = true # sandbox; set false in prod

  image_scanning_configuration {
    scan_on_push = each.value.scan_on_push
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-${each.key}"
  }
}

resource "aws_ecr_lifecycle_policy" "repos" {
  for_each = var.repositories

  repository = aws_ecr_repository.repos[each.key].name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 10 images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 10
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}