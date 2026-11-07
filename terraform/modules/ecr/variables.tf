variable "project_name" { type = string }
variable "environment" { type = string }

variable "repositories" {
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
