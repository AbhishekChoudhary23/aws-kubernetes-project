# output "vpc_id" {
#   description = "VPC ID"
#   value       = module.vpc.vpc_id
# }

# output "eks_cluster_endpoint" {
#   description = "EKS cluster endpoint"
#   value       = module.eks.cluster_endpoint
# }

# output "eks_cluster_name" {
#   description = "EKS cluster name"
#   value       = module.eks.cluster_name
# }

# output "ecr_backend_repository_uri" {
#   description = "ECR backend repository URI"
#   value       = module.ecr.backend_repository_uri
# }

# output "ecr_frontend_repository_uri" {
#   description = "ECR frontend repository URI"
#   value       = module.ecr.frontend_repository_uri
# }

# output "kubeconfig_command" {
#   description = "Command to update kubeconfig"
#   value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${var.cluster_name}"
# }



output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

# output "eks_cluster_endpoint" {
#   description = "EKS cluster endpoint"
#   value       = module.eks.cluster_endpoint
# }

# output "eks_cluster_name" {
#   description = "EKS cluster name"
#   value       = module.eks.cluster_name
# }

output "ecr_backend_repository_uri" {
  description = "ECR backend repository URI"
  value       = module.ecr.backend_repository_uri
}

output "ecr_frontend_repository_uri" {
  description = "ECR frontend repository URI"
  value       = module.ecr.frontend_repository_uri
}

# output "kubeconfig_command" {
#   description = "Command to update kubeconfig"
#   value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${var.cluster_name}"
# }