provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

data "aws_caller_identity" "current" {}

# ─── VPC ──────────────────────────────────────────────────────────────────────
module "vpc" {
  source = "./modules/vpc"

  project_name         = var.project_name
  environment          = var.environment
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  availability_zones   = var.availability_zones
  enable_nat_gateway   = var.enable_nat_gateway
  single_nat_gateway   = var.single_nat_gateway
  cluster_name         = var.cluster_name
}

# ─── IAM ──────────────────────────────────────────────────────────────────────
module "iam" {
  source = "./modules/iam"

  project_name        = var.project_name
  environment         = var.environment
  cluster_name        = var.cluster_name
  aws_region          = var.aws_region
  account_id          = data.aws_caller_identity.current.account_id
  enable_codepipeline = var.enable_codepipeline
}

# ─── EKS (Optional via Terraform if not deploying via CloudFormation) ─────────
module "eks" {
  count  = var.create_eks_via_terraform ? 1 : 0
  source = "./modules/eks"

  project_name         = var.project_name
  environment          = var.environment
  cluster_name         = var.cluster_name
  cluster_version      = var.cluster_version
  vpc_id               = module.vpc.vpc_id
  private_subnet_ids   = module.vpc.private_subnet_ids
  public_subnet_ids    = module.vpc.public_subnet_ids
  node_groups          = var.node_groups
  eks_cluster_role_arn = module.iam.eks_cluster_role_arn
  eks_node_role_arn    = module.iam.eks_node_role_arn
}

# ─── CodePipeline (Optional CI/CD pushing to GitHub Container Registry) ───────
module "codepipeline" {
  count  = var.enable_codepipeline ? 1 : 0
  source = "./modules/codepipeline"

  project_name            = var.project_name
  environment             = var.environment
  aws_region              = var.aws_region
  account_id              = data.aws_caller_identity.current.account_id
  github_owner            = var.github_owner
  github_repo             = var.github_repo
  github_branch           = var.github_branch
  gitops_repo             = var.gitops_repo
  gitops_branch           = var.gitops_branch
  codestar_connection_arn = var.codestar_connection_arn
  ghcr_host               = var.ghcr_host
  ghcr_owner              = lower(var.github_owner)
  codebuild_role_arn      = module.iam.codebuild_role_arn
  codepipeline_role_arn   = module.iam.codepipeline_role_arn
}
