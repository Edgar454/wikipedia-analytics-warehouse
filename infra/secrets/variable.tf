variable "project_name" {
  type = string
}

variable "tags" {
  type = map(string)
}

variable "gcp_service_account_json" {
  type      = string
  sensitive = true
}

variable "powerbi_credentials_json" {
  type      = string
  sensitive = true
}