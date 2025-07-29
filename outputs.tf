output "storage_web_url" {
  value = azurerm_storage_account.primary.primary_web_endpoint
}

output "frontdoor_url" {
  value = "https://${azurerm_cdn_frontdoor_endpoint.fd_endpoint.host_name}"
}
