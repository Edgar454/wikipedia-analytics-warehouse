variable "region" {
  type = string
}

# ecr config
variable "project_name" {
  type = string
}

#s3 config
variable "bucket_name" {
  type = string
}

# secrets config
variable "gcp_service_account_json" {
  type      = string
  sensitive = true
}

#iam config
variable "github_repository_path" {
  type      = string
}