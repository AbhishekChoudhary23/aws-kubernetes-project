# output "eks_cluster_role_arn" {
#   value = aws_iam_role.eks_cluster.arn
# }

# output "eks_node_role_arn" {
#   value = aws_iam_role.eks_node.arn
# }

# output "codebuild_role_arn" {
#   value = aws_iam_role.codebuild.arn
# }

# output "codepipeline_role_arn" {
#   value = aws_iam_role.codepipeline.arn
# }

output "eks_cluster_role_arn" {
  value = aws_iam_role.eks_cluster.arn
}

output "eks_node_role_arn" {
  value = aws_iam_role.eks_node.arn
}