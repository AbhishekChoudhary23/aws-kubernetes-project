output "eks_cluster_role_arn" {
  value = aws_iam_role.eks_cluster.arn
}

output "eks_node_role_arn" {
  value = aws_iam_role.eks_nodes.arn
}

output "codebuild_role_arn" {
  value = var.enable_codepipeline ? aws_iam_role.codebuild[0].arn : ""
}

output "codepipeline_role_arn" {
  value = var.enable_codepipeline ? aws_iam_role.codepipeline[0].arn : ""
}
