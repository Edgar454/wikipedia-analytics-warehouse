resource "aws_iam_policy" "powerbi_secrets_access" {
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
  role       = var.ecs_task_role_name
  policy_arn = aws_iam_policy.powerbi_secrets_access.arn
}