resource "aws_iam_policy" "powerbi_secrets_access" {
  count = var.powerbi_secret_arn != null ? 1 : 0
  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [{
      Effect = "Allow"

      Action = [
        "secretsmanager:GetSecretValue"
      ]

      Resource = [ var.powerbi_secret_arn ]
    }]
  })
}

resource "aws_iam_role_policy_attachment" "attach_secrets_access" {
  count = var.powerbi_secret_arn != null ? 1 : 0
  role       = var.ecs_task_role_name
  policy_arn = aws_iam_policy.powerbi_secrets_access[0].arn
}