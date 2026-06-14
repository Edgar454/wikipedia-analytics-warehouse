variable "project_name" {
  type = string
}

variable "ecs_cluster_arn" {
  type = string
}

variable "task_definition_arn" {
  type = string
}

variable "ecs_execution_role_arn" {
  type = string
}

variable "ecs_task_role_arn" {
  type = string
}

variable "subnets" {
  type = list(string)
}

variable "security_group_id" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}