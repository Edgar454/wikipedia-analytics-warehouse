module "secrets" {
  source = "./secrets"

  project_name             = var.project_name
  tags                     = var.tags
  powerbi_credentials_json = var.powerbi_credentials_json
}

module "iam" {
  source = "./iam"

  ecs_task_role_name       = var.ecs_task_role_name
  powerbi_secret_arn       = module.secrets.powerbi_credentials_json 
}