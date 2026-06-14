resource "aws_cloudwatch_event_rule" "dbt_schedule" {
  name                = "${var.project_name}-dbt-daily"
  description         = "Run dbt pipeline daily at 2 AM UTC"
  schedule_expression = "cron(0 2 * * ? *)"

  tags = var.tags
}

resource "aws_cloudwatch_event_target" "dbt_task" {
  rule      = aws_cloudwatch_event_rule.dbt_schedule.name
  target_id = "dbt-runner"
  arn       = var.ecs_cluster_arn
  role_arn  = aws_iam_role.eventbridge_ecs_role.arn

  ecs_target {
    task_definition_arn = var.task_definition_arn
    launch_type         = "FARGATE"
    task_count          = 1

    network_configuration {
      subnets          = var.subnets
      security_groups  = [var.security_group_id]
      assign_public_ip = true
    }
  }
}

resource "aws_iam_role" "eventbridge_ecs_role" {
  name = "${var.project_name}-eventbridge-ecs-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "events.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = var.tags
}

resource "aws_iam_policy" "eventbridge_ecs_policy" {
  name = "${var.project_name}-eventbridge-ecs"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [

      {
        Effect = "Allow"
        Action = [
          "ecs:RunTask"
        ]
        Resource = var.task_definition_arn
      },

      {
        Effect = "Allow"
        Action = [
          "iam:PassRole"
        ]
        Resource = [
          var.ecs_execution_role_arn,
          var.ecs_task_role_arn
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "eventbridge_attach" {
  role       = aws_iam_role.eventbridge_ecs_role.name
  policy_arn = aws_iam_policy.eventbridge_ecs_policy.arn
}