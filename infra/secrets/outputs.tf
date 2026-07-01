output "gcp_service_account_secret_arn" {
  value = aws_secretsmanager_secret.gcp_service_account.arn
}

output "gcp_service_account_secret_name" {
  value = aws_secretsmanager_secret.gcp_service_account.name
}

