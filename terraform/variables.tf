# ─── General ──────────────────────────────────────────────────────────────────
variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-south-1"
}

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "observability"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "sandbox"
}

# ─── VPC ──────────────────────────────────────────────────────────────────────
variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "Public subnet CIDR blocks"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "Private subnet CIDR blocks"
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.11.0/24"]
}

variable "availability_zones" {
  description = "Availability zones"
  type        = list(string)
  default     = ["ap-south-1a", "ap-south-1b"]
}

variable "enable_nat_gateway" {
  description = "Enable NAT Gateway for private subnets"
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "Use a single NAT Gateway to reduce costs in sandbox environments"
  type        = bool
  default     = true
}

# ─── EKS ──────────────────────────────────────────────────────────────────────
variable "create_eks_via_terraform" {
  description = "Set to true to provision EKS via Terraform, or false when provisioning EKS via CloudFormation"
  type        = bool
  default     = false
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
  default     = "observability-eks"
}

variable "cluster_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.31"
}

variable "node_groups" {
  description = "EKS node group configurations"
  type = map(object({
    instance_types = list(string)
    capacity_type  = string
    desired_size   = number
    min_size       = number
    max_size       = number
    disk_size      = number
  }))
  default = {
    general = {
      instance_types = ["m7i-flex.large"]
      capacity_type  = "ON_DEMAND"
      desired_size   = 2
      min_size       = 2
      max_size       = 3
      disk_size      = 30
    }
  }
}

# ─── GCR & CodePipeline ───────────────────────────────────────────────────────
variable "enable_codepipeline" {
  description = "Enable AWS CodePipeline and CodeBuild for GCR image builds"
  type        = bool
  default     = false
}

variable "gcr_host" {
  description = "Google Container Registry hostname (e.g., gcr.io, us.gcr.io, asia.gcr.io)"
  type        = string
  default     = "gcr.io"
}

variable "gcp_project_id" {
  description = "Google Cloud Project ID hosting the GCR registry"
  type        = string
  default     = "my-gcp-project"
}

variable "github_owner" {
  description = "GitHub repository owner"
  type        = string
  default     = "AbhishekChoudhary23"
}

variable "github_repo" {
  description = "GitHub application repository name"
  type        = string
  default     = "aws-kubernetes-project"
}

variable "github_branch" {
  description = "GitHub branch to build from"
  type        = string
  default     = "master"
}

variable "gitops_repo" {
  description = "GitOps repository (owner/repo format)"
  type        = string
  default     = "AbhishekChoudhary23/DevOps-Observability-k8s-gitops-manifest"
}

variable "gitops_branch" {
  description = "GitOps repository branch"
  type        = string
  default     = "main"
}

variable "codestar_connection_arn" {
  description = "CodeStar connection ARN for GitHub"
  type        = string
  default     = ""
}
