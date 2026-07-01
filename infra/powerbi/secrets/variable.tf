variable "project_name" {
  type = string
}

variable "tags" {
  type = map(string)
}

variable "enabled" {
  type      = bool
}

variable "powerbi_credentials_json" {
  type      = string
  sensitive = true
}

