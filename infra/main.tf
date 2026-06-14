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
  github_oidc_assume_json   = data.aws_iam_policy_document.github_oidc_assume.json
  ecr_repository_arn       = module.ecr.repository_arn
  gcp_service_account_secret_arn = module.secrets.gcp_service_account_secret_arn
}

module "s3" {
  source = "./s3"
  
  bucket_name             = var.bucket_name
  tags                     = local.common_tags
}

module "cloudwatch" {

  source = "./cloudwatch"

  project_name = var.project_name
  tags         = local.common_tags
}

module "ecs" {
  source = "./ecs"

  ecr_repository_url = module.ecr.repository_url
  log_group_name     = module.cloudwatch.log_group_name
  secret_arn         = module.secrets.gcp_secret_arn
}

module "eventbridge" {
  source = "./eventbridge"

  ecs_cluster_arn = module.ecs.cluster_arn
  task_arn        = module.ecs.task_definition_arn
}