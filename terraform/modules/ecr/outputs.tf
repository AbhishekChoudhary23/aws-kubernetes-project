output "repository_uris" {
  description = "Map of repository name to URI"
  value       = { for k, v in aws_ecr_repository.repos : k => v.repository_url }
}

output "repository_names" {
  description = "Map of repository name to ECR name"
  value       = { for k, v in aws_ecr_repository.repos : k => v.name }
}

output "repository_arns" {
  description = "Map of repository name to ARN"
  value       = { for k, v in aws_ecr_repository.repos : k => v.arn }
}

output "backend_repository_uri" {
  value = aws_ecr_repository.repos["backend"].repository_url
}

output "frontend_repository_uri" {
  value = aws_ecr_repository.repos["frontend"].repository_url
}
