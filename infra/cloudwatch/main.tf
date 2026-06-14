resource "aws_cloudwatch_log_group" "dbt_runner" {

  name = "/ecs/${var.project_name}"
  retention_in_days = var.retention_in_days

  tags = var.tags
}