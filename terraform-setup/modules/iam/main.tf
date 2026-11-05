# # ─── EKS Cluster Role ────────────────────────────────────
# resource "aws_iam_role" "eks_cluster" {
#   name = "${var.project_name}-${var.environment}-eks-cluster-role"

#   assume_role_policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Action = "sts:AssumeRole"
#         Effect = "Allow"
#         Principal = {
#           Service = "eks.amazonaws.com"
#         }
#       }
#     ]
#   })
# }

# resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
#   policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
#   role       = aws_iam_role.eks_cluster.name
# }

# resource "aws_iam_role_policy_attachment" "eks_vpc_resource_controller" {
#   policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
#   role       = aws_iam_role.eks_cluster.name
# }

# # ─── EKS Node Role ───────────────────────────────────────
# resource "aws_iam_role" "eks_node" {
#   name = "${var.project_name}-${var.environment}-eks-node-role"

#   assume_role_policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Action = "sts:AssumeRole"
#         Effect = "Allow"
#         Principal = {
#           Service = "ec2.amazonaws.com"
#         }
#       }
#     ]
#   })
# }

# resource "aws_iam_role_policy_attachment" "eks_worker_node_policy" {
#   policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
#   role       = aws_iam_role.eks_node.name
# }

# resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
#   policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
#   role       = aws_iam_role.eks_node.name
# }

# resource "aws_iam_role_policy_attachment" "eks_container_registry" {
#   policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
#   role       = aws_iam_role.eks_node.name
# }

# # ─── CodeBuild Role ──────────────────────────────────────
# resource "aws_iam_role" "codebuild" {
#   name = "${var.project_name}-${var.environment}-codebuild-role"

#   assume_role_policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Action = "sts:AssumeRole"
#         Effect = "Allow"
#         Principal = {
#           Service = "codebuild.amazonaws.com"
#         }
#       }
#     ]
#   })
# }

# resource "aws_iam_role_policy" "codebuild_policy" {
#   name = "${var.project_name}-${var.environment}-codebuild-policy"
#   role = aws_iam_role.codebuild.id

#   policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Sid = "CloudWatchLogs"
#         Effect = "Allow"
#         Action = [
#           "logs:CreateLogGroup",
#           "logs:CreateLogStream",
#           "logs:PutLogEvents"
#         ]
#         Resource = "arn:aws:logs:${var.aws_region}:${var.account_id}:log-group:/aws/codebuild/*"
#       },
#       {
#         Sid      = "ECRAuth"
#         Effect   = "Allow"
#         Action   = ["ecr:GetAuthorizationToken"]
#         Resource = "*"
#       },
#       {
#         Sid    = "ECRPush"
#         Effect = "Allow"
#         Action = [
#           "ecr:BatchCheckLayerAvailability",
#           "ecr:GetDownloadUrlForLayer",
#           "ecr:BatchGetImage",
#           "ecr:PutImage",
#           "ecr:InitiateLayerUpload",
#           "ecr:UploadLayerPart",
#           "ecr:CompleteLayerUpload"
#         ]
#         Resource = "arn:aws:ecr:${var.aws_region}:${var.account_id}:repository/*"
#       },
#       {
#         Sid    = "S3Artifacts"
#         Effect = "Allow"
#         Action = [
#           "s3:GetObject",
#           "s3:GetObjectVersion",
#           "s3:PutObject",
#           "s3:GetBucketAcl",
#           "s3:GetBucketLocation"
#         ]
#         Resource = [
#           "arn:aws:s3:::${var.project_name}-${var.environment}-pipeline-artifacts",
#           "arn:aws:s3:::${var.project_name}-${var.environment}-pipeline-artifacts/*"
#         ]
#       },
#       {
#         Sid    = "SecretsManager"
#         Effect = "Allow"
#         Action = [
#           "secretsmanager:GetSecretValue"
#         ]
#         Resource = "arn:aws:secretsmanager:${var.aws_region}:${var.account_id}:secret:${var.project_name}/*"
#       }
#     ]
#   })
# }

# # ─── CodePipeline Role ──────────────────────────────────
# resource "aws_iam_role" "codepipeline" {
#   name = "${var.project_name}-${var.environment}-codepipeline-role"

#   assume_role_policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Action = "sts:AssumeRole"
#         Effect = "Allow"
#         Principal = {
#           Service = "codepipeline.amazonaws.com"
#         }
#       }
#     ]
#   })
# }

# resource "aws_iam_role_policy" "codepipeline_policy" {
#   name = "${var.project_name}-${var.environment}-codepipeline-policy"
#   role = aws_iam_role.codepipeline.id

#   policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Sid    = "S3Artifacts"
#         Effect = "Allow"
#         Action = [
#           "s3:GetObject",
#           "s3:GetObjectVersion",
#           "s3:PutObject",
#           "s3:GetBucketAcl",
#           "s3:GetBucketLocation"
#         ]
#         Resource = [
#           "arn:aws:s3:::${var.project_name}-${var.environment}-pipeline-artifacts",
#           "arn:aws:s3:::${var.project_name}-${var.environment}-pipeline-artifacts/*"
#         ]
#       },
#       {
#         Sid    = "CodeBuild"
#         Effect = "Allow"
#         Action = [
#           "codebuild:BatchGetBuilds",
#           "codebuild:StartBuild"
#         ]
#         Resource = "*"
#       },
#       {
#         Sid      = "CodeStarConnection"
#         Effect   = "Allow"
#         Action   = ["codestar-connections:UseConnection"]
#         Resource = "*"
#       }
#     ]
#   })
# }



# ─── EKS Cluster Role ────────────────────────────────────
resource "aws_iam_role" "eks_cluster" {
  name = "${var.project_name}-${var.environment}-eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster.name
}

resource "aws_iam_role_policy_attachment" "eks_vpc_resource_controller" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
  role       = aws_iam_role.eks_cluster.name
}

# ─── EKS Node Role ───────────────────────────────────────
resource "aws_iam_role" "eks_node" {
  name = "${var.project_name}-${var.environment}-eks-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "eks_worker_node_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_node.name
}

resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_node.name
}

resource "aws_iam_role_policy_attachment" "eks_container_registry" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPullOnly"
  role       = aws_iam_role.eks_node.name
}
