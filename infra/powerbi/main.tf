module "secrets" {
  source = "./secrets"

  enabled = local.powerbi_enabled
  project_name             = var.project_name
  tags                     = var.tags
  powerbi_credentials_json = var.powerbi_credentials_json
}

module "iam" {
  source = "./iam"
  
  enabled = local.powerbi_enabled
  ecs_task_role_name       = var.ecs_task_role_name
  powerbi_secret_arn       = module.secrets.powerbi_credentials_secret_arn 
}