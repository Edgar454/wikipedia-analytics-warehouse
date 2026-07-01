locals {
  powerbi_enabled = trimspace(coalesce(var.powerbi_credentials_json, "")) != ""
}