resource "aws_iam_role" "github_bootstrap_role" {
  name               = "github-bootstrap-role"
  assume_role_policy = data.aws_iam_policy_document.github_oidc_assume.json
}

resource "aws_iam_policy" "terraform_bootstrap" {

  name = "terraform-bootstrap"

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

        "secretsmanager:*",

        "budgets:*",

        "s3:*",

        "cloudfront:*",

        "ec2:Describe*",

        "ec2:CreateSecurityGroup",
        "ec2:DeleteSecurityGroup",

        "ec2:AuthorizeSecurityGroupIngress",
        "ec2:AuthorizeSecurityGroupEgress",

        "ec2:RevokeSecurityGroupIngress",
        "ec2:RevokeSecurityGroupEgress",

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