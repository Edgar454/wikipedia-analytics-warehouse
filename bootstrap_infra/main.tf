resource "aws_iam_role" "github_bootstrap_role" {
  name               = "github-bootstrap-role"
  assume_role_policy = data.aws_iam_policy_document.github_oidc_assume.json
}

resource "aws_iam_policy" "terraform_bootstrap" {

  name = "github-terraform-bootstrap"

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [{
      Effect = "Allow"

      Action = [

        "iam:*",

        "ecs:*",
        "ecr:*",

        "events:*",

        "logs:*",
        "cloudwatch:*",

        "sns:*",

        "budgets:*",

        "secretsmanager:*",

        "s3:*",

        "cloudfront:*",

        "ec2:*",

        "tag:*"
      ]

      Resource = "*"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "bootstrap" {
  role       = aws_iam_role.github_bootstrap_role.name
  policy_arn = aws_iam_policy.terraform_bootstrap.arn
}