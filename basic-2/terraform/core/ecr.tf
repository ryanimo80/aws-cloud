# ECR Repositories for Django Microservices
# Phase 2: Core Infrastructure

# ECR Repositories for each microservice
resource "aws_ecr_repository" "microservices" {
  for_each = var.microservices

  name                 = "${var.project_name}-${each.value}"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name        = "${var.project_name}-${each.value}"
    Environment = var.environment
    Project     = var.project_name
    Service     = each.value
  }
}

# ECR Lifecycle Policy
resource "aws_ecr_lifecycle_policy" "microservices" {
  for_each = var.microservices

  repository = aws_ecr_repository.microservices[each.key].name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 10 images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["v"]
          countType     = "imageCountMoreThan"
          countNumber   = 10
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2
        description  = "Keep last 5 untagged images"
        selection = {
          tagStatus   = "untagged"
          countType   = "imageCountMoreThan"
          countNumber = 5
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

# ECR Repository Policy (for cross-account access if needed)
resource "aws_ecr_repository_policy" "microservices" {
  for_each = var.microservices

  repository = aws_ecr_repository.microservices[each.key].name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowPullForECS"
        Effect = "Allow"
        Principal = {
          AWS = [
            aws_iam_role.ecs_task_execution_role.arn,
            aws_iam_role.ecs_task_role.arn
          ]
        }
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage"
        ]
      }
    ]
  })
} 