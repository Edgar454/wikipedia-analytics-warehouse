variable "project_name" {
  type = string
}

variable "tags" {
  type = map(string)
  default = {}
}

variable "github_oidc_assume_json" {
  type      = string
}

variable "ecr_repository_arn" {
  type = string
}

variable "gcp_service_account_secret_arn" {
  type = string
}