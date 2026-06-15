variable "region" {
  type = string
}

# ecr config
variable "project_name" {
  type = string
}

#s3 config
variable "bucket_name" {
  type = string
}

# secrets config
variable "gcp_service_account_json" {
  type      = string
  sensitive = true
}



# ecr image
variable "ecr_image" {
  type      = string
}

# sns alert email
variable "alert_email" {
  type = string
}