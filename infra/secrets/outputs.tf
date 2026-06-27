output "gcp_service_account_secret_arn" {
  value = aws_secretsmanager_secret.gcp_service_account.arn
}

output "gcp_service_account_secret_name" {
  value = aws_secretsmanager_secret.gcp_service_account.name
}

output "powerbi_credentials_arn" {
  value = try(
    aws_secretsmanager_secret.powerbi_credentials[0].arn,
    null
  )
}


output "powerbi_credentials" {
  value =  try(
    aws_secretsmanager_secret.powerbi_credentials[0].name,
    null
  )
}