output "powerbi_credentials_secret_arn" {
  value = try(
    aws_secretsmanager_secret.powerbi_credentials[0].arn,
    null
  )
}

output "powerbi_credentials_secret_name" {
  value =  try(
    aws_secretsmanager_secret.powerbi_credentials[0].name,
    null
  )
}