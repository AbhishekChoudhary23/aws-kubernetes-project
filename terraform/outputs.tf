output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "List of public subnet IDs"
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "List of private subnet IDs"
  value       = module.vpc.private_subnet_ids
}

output "eks_cluster_role_arn" {
  description = "IAM Role ARN for EKS Cluster Control Plane (pass to CloudFormation)"
  value       = module.iam.eks_cluster_role_arn
}

output "eks_node_role_arn" {
  description = "IAM Role ARN for EKS Worker Nodes (pass to CloudFormation)"
  value       = module.iam.eks_node_role_arn
}

output "kubeconfig_command" {
  description = "Command to configure local kubeconfig"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${var.cluster_name}"
}
