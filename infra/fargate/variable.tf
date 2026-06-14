variable "project_name" {
  type = string
}

variable "ecs_execution_role_arn" {
  type = string
}

variable "ecs_task_role_arn" {
  type = string
}

variable "ecr_image" {
  type = string
}

variable "gcp_secret_name" {
  type = string
}

variable "log_group_name" {
  type = string
}

variable "region" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}