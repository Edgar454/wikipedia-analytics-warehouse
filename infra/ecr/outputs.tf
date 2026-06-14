output "repository_url" {
  value = aws_ecr_repository.dbt_runner.repository_url
}

output "repository_name" {
  value = aws_ecr_repository.dbt_runner.name
}

output "repository_arn" {
  value = aws_ecr_repository.dbt_runner.arn
}