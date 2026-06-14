# ecr outputs

output "repository_url" {
  value = module.ecr.repository_url
}

output "repository_name" {
  value = module.ecr.repository_name
}

output "repository_arn" {
  value = module.ecr.repository_arn
}

# secrets outputs
output "gcp_service_account_secret_arn" {
  value = module.secrets.gcp_service_account_secret_arn
}

output "gcp_service_account_secret_name" {
  value = module.secrets.gcp_service_account_secret_name
}

#s3 outputs
output "s3_bucket_name" {
  value = module.s3.s3_bucket_name
}

#iam outputs
output "ecs_execution_role_arn" {
  value = module.iam.ecs_execution_role_arn
}

output "ecs_task_role_arn" {
  value = module.iam.ecs_task_role_arn
}

output "github_actions_role_arn" {
  value = module.iam.github_actions_role_arn
}

#cloudwatch outputs
output "log_group_name" {
  value = module.cloudwatch.log_group_name
}

output "log_group_arn" {
  value = module.cloudwatch.log_group_arn
}