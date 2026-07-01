output "powerbi_credentials_secret_arn" {
  value = aws_secretsmanager_secret.powerbi_credentials[0].arn
}

output "powerbi_credentials_secret_name" {
  value =  aws_secretsmanager_secret.powerbi_credentials[0].name
}