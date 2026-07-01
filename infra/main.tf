module "ecr" {
  source = "./ecr"

  project_name = var.project_name
  tags         = local.common_tags
}

module "secrets" {
  source = "./secrets"

  project_name             = var.project_name
  tags                     = local.common_tags
  gcp_service_account_json = var.gcp_service_account_json
}

module "iam" {
  source = "./iam"
  
  project_name             = var.project_name
  tags                     = local.common_tags
  ecr_repository_arn       = module.ecr.repository_arn
  gcp_secret_arn           = module.secrets.gcp_service_account_secret_arn 
}

module "powerbi_infra" {
  source = "./powerbi"

  count = var.powerbi_credentials_json != null ? 1 : 0
  project_name             = var.project_name
  tags                     = local.common_tags
  ecs_task_role_name       = module.iam.ecs_task_role_name
  powerbi_credentials_json = var.powerbi_credentials_json
}


module "cloudwatch" {

  source = "./cloudwatch"

  project_name = var.project_name
  tags         = local.common_tags
  sns_topic_arn = module.sns.topic_arn
}

module "ecs_cluster" {
  source = "./ecs_cluster"
  project_name = var.project_name
  tags         = local.common_tags
  
}

module "fargate" {
  source = "./fargate"

  project_name = var.project_name
  region = var.region
  tags         = local.common_tags
  ecs_execution_role_arn = module.iam.ecs_execution_role_arn
  ecs_task_role_arn = module.iam.ecs_task_role_arn
  ecr_image     =  "${module.ecr.repository_url}:latest"
  gcp_secret_name = module.secrets.gcp_service_account_secret_name
  powerbi_secret_name =  var.powerbi_credentials_json != null ? module.powerbi_infra[0].powerbi_credentials_secret_name : null
  log_group_name = module.cloudwatch.log_group_name
 
}

module "network" {
  source = "./network"
  project_name = var.project_name
  region = var.region
  tags         = local.common_tags
}

module "eventbridge" {
  source = "./eventbridge"

  project_name = var.project_name
  tags         = local.common_tags
  ecs_cluster_arn = module.ecs_cluster.cluster_arn
  task_definition_arn        = module.fargate.task_definition_arn
  ecs_execution_role_arn = module.iam.ecs_execution_role_arn
  ecs_task_role_arn = module.iam.ecs_task_role_arn
  subnets   = module.network.subnets
  security_group_id = module.network.security_group_id
}

module "sns" {
  source = "./sns"
  
  project_name = var.project_name
  tags         = local.common_tags
  alert_email = var.alert_email
}

module "budget" {
  source = "./budget"

  project_name = var.project_name
  monthly_budget = 10
  sns_topic_arn = module.sns.topic_arn
}