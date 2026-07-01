locals {
  powerbi_enabled = (
    var.powerbi_credentials_json != null &&
    trimspace(var.powerbi_credentials_json) != ""
  )
}