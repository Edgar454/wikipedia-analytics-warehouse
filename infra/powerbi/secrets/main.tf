resource "aws_secretsmanager_secret" "powerbi_credentials" {
  name        = "${var.project_name}-powerbi-credentials"
  description = "Power BI OAuth application credentials"
  tags        = var.tags
}

resource "aws_secretsmanager_secret_version" "powerbi_credentials" {
  count = var.enabled ? 1 : 0

  secret_id     = aws_secretsmanager_secret.powerbi_credentials.id
  secret_string = var.powerbi_credentials_json
}