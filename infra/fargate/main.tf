resource "aws_ecs_task_definition" "dbt_runner" {
  family                   = "${var.project_name}-dbt-runner"
  requires_compatibilities = ["FARGATE"]
  network_mode            = "awsvpc"
  cpu                     = 1024
  memory                  = 2048
  execution_role_arn      = var.ecs_execution_role_arn
  task_role_arn           = var.ecs_task_role_arn

  container_definitions = jsonencode([
    {
      name      = "dbt-runner"
      image     = var.ecr_image
      essential = true

      environment = concat(
        [
          {
            name  = "REGION"
            value = var.region
          },
          {
            name  = "GCP_SECRET_NAME"
            value = var.gcp_secret_name
          },
          {
            name  = "FARGATE_RUN_LOG_GROUP"
            value = var.log_group_name
          }
        ],
        var.powerbi_secret_name != null ? [
          {
            name  = "POWERBI_CREDENTIALS"
            value = var.powerbi_secret_name
          }
        ] : []
      )

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = var.log_group_name
          awslogs-region        = var.region
          awslogs-stream-prefix = "dbt"
        }
      }
    }
  ])

  tags = var.tags
}