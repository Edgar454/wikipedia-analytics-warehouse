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

#iam outputs
output "ecs_execution_role_arn" {
  value = module.iam.ecs_execution_role_arn
}

output "ecs_task_role_arn" {
  value = module.iam.ecs_task_role_arn
}



#cloudwatch outputs
output "log_group_name" {
  value = module.cloudwatch.log_group_name
}

output "log_group_arn" {
  value = module.cloudwatch.log_group_arn
}

#ecs cluster 
output "cluster_id" {
  value = module.ecs_cluster.cluster_id
}

output "cluster_arn" {
  value = module.ecs_cluster.cluster_arn
}

output "cluster_name" {
  value = module.ecs_cluster.cluster_name
}

#fargate task 
output "task_definition_arn" {
  value = module.fargate.task_definition_arn
}

# networking 
output "vpc_id" {
  value = module.network.vpc_id
}

output "subnets" {
  value = module.network.subnets
}

output "security_group_id" {
  value = module.network.security_group_id
}

# budget
output "budget_name" {
  value = module.budget.budget_name
}

#ci config
output "ci_config" {
  value = {
    ecr_url = module.ecr.repository_url
    cluster = module.ecs_cluster.cluster_name
  }
}