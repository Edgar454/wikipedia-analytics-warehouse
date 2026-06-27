variable "project_name" {
  type = string
}

variable "tags" {
  type = map(string)
  default = {}
}


variable "ecr_repository_arn" {
  type = string
}

variable "secret_arns" {
  type = list(string)
}