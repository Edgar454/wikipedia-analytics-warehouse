resource "aws_secretsmanager_secret" "gcp_service_account" {
  name        = "${var.project_name}-gcp-service-account"
  description = "Google Cloud service account credentials"
  tags        = var.tags
}

resource "aws_secretsmanager_secret_version" "gcp_service_account" {
  secret_id     = aws_secretsmanager_secret.gcp_service_account.id
  secret_string = var.gcp_service_account_json
}

