variable "project_name" {
  type = string
}

variable "tags" {
  type = map(string)
}

variable "ecs_task_role_name" {
  type= string
}

variable "powerbi_credentials_json" {
  type      = string
  sensitive = true
}