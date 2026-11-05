variable "project_name" { type = string }
variable "environment" { type = string }
variable "cluster_name" { type = string }
variable "aws_region" { type = string }
variable "account_id" { type = string }
variable "enable_codepipeline" {
  type    = bool
  default = false
}
