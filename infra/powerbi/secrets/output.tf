output "powerbi_credentials_secret_arn" {
  value = length(aws_secretsmanager_secret.powerbi_credentials) > 0 ? aws_secretsmanager_secret.powerbi_credentials[0].arn : null
}

output "powerbi_credentials_secret_name" {
  value = length(aws_secretsmanager_secret.powerbi_credentials) > 0 ? aws_secretsmanager_secret.powerbi_credentials[0].name : null
}