resource "aws_secretsmanager_secret" "powerbi_credentials" {
  count = var.powerbi_credentials_json == null ? 0 : 1

  name        = "${var.project_name}-powerbi-credentials"
  description = "Power BI OAuth application credentials"
  tags        = var.tags
}

resource "aws_secretsmanager_secret_version" "powerbi_credentials" {
  count = var.powerbi_credentials_json == null ? 0 : 1

  secret_id     = aws_secretsmanager_secret.powerbi_credentials[0].id
  secret_string = var.powerbi_credentials_json
}

