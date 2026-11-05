# # ─── General ───────────────────────────────────────────────
# variable "aws_region" {
#   description = "AWS region"
#   type        = string
#   default     = "ap-south-1"
# }

# variable "project_name" {
#   description = "Project name used for resource naming"
#   type        = string
#   default     = "observability"
# }

# variable "environment" {
#   description = "Environment name"
#   type        = string
#   default     = "sandbox"
# }

# # ─── VPC ───────────────────────────────────────────────────
# variable "vpc_cidr" {
#   description = "VPC CIDR block"
#   type        = string
#   default     = "10.0.0.0/16"
# }

# variable "public_subnet_cidrs" {
#   description = "Public subnet CIDR blocks"
#   type        = list(string)
#   default     = ["10.0.1.0/24", "10.0.2.0/24"]
# }

# variable "private_subnet_cidrs" {
#   description = "Private subnet CIDR blocks"
#   type        = list(string)
#   default     = ["10.0.10.0/24", "10.0.11.0/24"]
# }

# variable "availability_zones" {
#   description = "Availability zones"
#   type        = list(string)
#   default     = ["ap-south-1a", "ap-south-1b"]
# }

# variable "enable_nat_gateway" {
#   description = "Enable NAT Gateway"
#   type        = bool
#   default     = true
# }

# variable "single_nat_gateway" {
#   description = "Use single NAT Gateway (cost saving)"
#   type        = bool
#   default     = true
# }

# # ─── EKS ───────────────────────────────────────────────────
# variable "cluster_name" {
#   description = "EKS cluster name"
#   type        = string
#   default     = "observability-eks"
# }

# variable "cluster_version" {
#   description = "Kubernetes version"
#   type        = string
#   default     = "1.29"
# }

# variable "node_groups" {
#   description = "EKS node group configurations"
#   type = map(object({
#     instance_types = list(string)
#     capacity_type  = string
#     desired_size   = number
#     min_size       = number
#     max_size       = number
#     disk_size      = number
#   }))
#   default = {
#     general = {
#       instance_types = ["t3.medium"]
#       capacity_type  = "SPOT"
#       desired_size   = 2
#       min_size       = 1
#       max_size       = 3
#       disk_size      = 20
#     }
#   }
# }

# # ─── ECR ───────────────────────────────────────────────────
# variable "ecr_repositories" {
#   description = "Map of ECR repositories to create"
#   type = map(object({
#     image_tag_mutability = string
#     scan_on_push         = bool
#   }))
#   default = {
#     backend = {
#       image_tag_mutability = "MUTABLE"
#       scan_on_push         = true
#     }
#     frontend = {
#       image_tag_mutability = "MUTABLE"
#       scan_on_push         = true
#     }
#   }
# }

# # ─── CodePipeline ─────────────────────────────────────────
# variable "github_owner" {
#   description = "GitHub repository owner"
#   type        = string
#   default     = "AbhishekChoudhary23"
# }

# variable "github_repo" {
#   description = "GitHub repository name"
#   type        = string
#   default     = "DevOps-Observability-app"
# }

# variable "github_branch" {
#   description = "GitHub branch to build from"
#   type        = string
#   default     = "prod"
# }

# variable "gitops_repo" {
#   description = "GitOps repository (owner/repo format)"
#   type        = string
#   default     = "AbhishekChoudhary23/DevOps-Observability-k8s-gitops-manifest"
# }

# variable "gitops_branch" {
#   description = "GitOps repository branch"
#   type        = string
#   default     = "main"
# }

# variable "codestar_connection_arn" {
#   description = "CodeStar connection ARN for GitHub"
#   type        = string
#   default     = ""
# }

# ─── General ───────────────────────────────────────────────
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

# ─── VPC ───────────────────────────────────────────────────
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
  description = "Enable NAT Gateway"
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "Use single NAT Gateway (cost saving)"
  type        = bool
  default     = true
}

# ─── EKS ───────────────────────────────────────────────────
variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
  default     = "observability-eks"
}

variable "cluster_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.29"
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
      instance_types = ["t3.medium"]
      capacity_type  = "ON_DEMAND"
      desired_size   = 2
      min_size       = 1
      max_size       = 2
      disk_size      = 20
    }
  }
}

# ─── ECR ───────────────────────────────────────────────────
variable "ecr_repositories" {
  description = "Map of ECR repositories to create"
  type = map(object({
    image_tag_mutability = string
    scan_on_push         = bool
  }))
  default = {
    backend = {
      image_tag_mutability = "MUTABLE"
      scan_on_push         = true
    }
    frontend = {
      image_tag_mutability = "MUTABLE"
      scan_on_push         = true
    }
  }
}

# variable "kubernetes_api_cidr" {
#   description = "CIDR allowed to access the public EKS Kubernetes API endpoint"
#   type        = string

#   validation {
#     condition     = can(cidrhost(var.kubernetes_api_cidr, 0))
#     error_message = "kubernetes_api_cidr must be a valid CIDR block."
#   }
# }
