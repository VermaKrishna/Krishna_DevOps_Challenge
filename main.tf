resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
}

resource "azurerm_storage_account" "primary" {
  name                     = "${var.app_name}prim"
  location                 = azurerm_resource_group.rg.location
  resource_group_name      = azurerm_resource_group.rg.name
  account_tier             = "Standard"
  account_replication_type = "RAGRS"

  tags = {
    environment = "prod"
  }
}

resource "azurerm_storage_account_static_website" "website" {
  storage_account_id = azurerm_storage_account.primary.id
  index_document     = "index.html"
  error_404_document = "404.html"
}

# Use $web to host static files
# resource "azurerm_storage_container" "static_web" {
#   name                  = "$web"
#   storage_account_id    = azurerm_storage_account.primary.id
#   container_access_type = "blob"
# }



resource "azurerm_storage_blob" "index_html" {
  name                   = "index.html"
  storage_account_name   = azurerm_storage_account.primary.name
  storage_container_name = "$web"
  type                   = "Block"
  source                 = "./webapp/index.html"
  content_type           = "text/html"
  
  depends_on = [azurerm_storage_account_static_website.website]
}

resource "azurerm_storage_blob" "error_html" {
  name                   = "404.html"
  storage_account_name   = azurerm_storage_account.primary.name
  storage_container_name = "$web"
  type                   = "Block"
  source                 = "./webapp/404.html"
  content_type           = "text/html"
  
  depends_on = [azurerm_storage_account_static_website.website]
}

resource "azurerm_cdn_frontdoor_profile" "fd_profile" {
  name                = "${var.app_name}-fd"
  resource_group_name = azurerm_resource_group.rg.name
  sku_name            = "Standard_AzureFrontDoor"
}

resource "azurerm_cdn_frontdoor_endpoint" "fd_endpoint" {
  name                      = "${var.app_name}-endpoint"
  cdn_frontdoor_profile_id  = azurerm_cdn_frontdoor_profile.fd_profile.id
  enabled                   = true
}

resource "azurerm_cdn_frontdoor_origin_group" "origin_group" { 
  name                     = "origin-group"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.fd_profile.id

  health_probe {
    protocol            = "Https"
    path                = "/index.html"
    request_type        = "GET"
    interval_in_seconds = 120
  }

  load_balancing {
    sample_size                         = 4
    successful_samples_required         = 3
    additional_latency_in_milliseconds  = 0
  }
}

resource "azurerm_cdn_frontdoor_origin" "primary_origin" {
  name                           = "primary-origin"
  cdn_frontdoor_origin_group_id  = azurerm_cdn_frontdoor_origin_group.origin_group.id
  host_name                      = azurerm_storage_account.primary.primary_web_host
  origin_host_header             = azurerm_storage_account.primary.primary_web_host
  http_port                      = 80
  https_port                     = 443
  certificate_name_check_enabled = false
  priority                       = 1
  weight                         = 1000
  enabled                        = true
}

# Rule Set to redirect "/" to "/index.html"
resource "azurerm_cdn_frontdoor_rule_set" "redirect_rules" {
  name                     = "redirectroot"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.fd_profile.id
}

resource "azurerm_cdn_frontdoor_rule" "redirect_root_to_index" {
  name                      = "redirectroot"
  cdn_frontdoor_rule_set_id = azurerm_cdn_frontdoor_rule_set.redirect_rules.id
  order                     = 1

  conditions {
    request_uri_condition {
      operator     = "Equal"
      match_values = ["/"]
    }
  }

  actions {
    url_redirect_action {
      redirect_type        = "Found"
      destination_path     = "/index.html"
      destination_hostname = azurerm_storage_account.primary.primary_web_host
    }
  }
}

resource "azurerm_cdn_frontdoor_route" "route" {
  name                          = "web-route"
  cdn_frontdoor_endpoint_id     = azurerm_cdn_frontdoor_endpoint.fd_endpoint.id
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.origin_group.id
  supported_protocols           = ["Http", "Https"]
  https_redirect_enabled        = true
  forwarding_protocol           = "MatchRequest"
  patterns_to_match             = ["/*"]
  link_to_default_domain        = true

  cdn_frontdoor_origin_ids = [azurerm_cdn_frontdoor_origin.primary_origin.id]

  # Conditionally assign custom domain IDs only if custom domain is enabled
  cdn_frontdoor_custom_domain_ids = var.enable_custom_domain ? [azurerm_cdn_frontdoor_custom_domain.custom_domain[0].id] : []
 # 👇 This helps Terraform destroy the route first before trying to delete the rule set
  cdn_frontdoor_rule_set_ids = [
    azurerm_cdn_frontdoor_rule_set.redirect_rules.id
  ]
}

resource "azurerm_log_analytics_workspace" "log_analytics" {
  name                = "${var.app_name}-law"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

resource "azurerm_monitor_diagnostic_setting" "fd_diagnostics" {
  name                       = "${var.app_name}-fd-diag"
  target_resource_id         = azurerm_cdn_frontdoor_profile.fd_profile.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.log_analytics.id

  depends_on = [
      azurerm_cdn_frontdoor_profile.fd_profile,
      azurerm_log_analytics_workspace.log_analytics
    ]
  enabled_log {
    category = "FrontDoorAccessLog"
  }

  enabled_log {
    category = "FrontDoorWebApplicationFirewallLog"
  }

  enabled_metric {
    category = "AllMetrics"
  }
}

resource "azurerm_cdn_frontdoor_custom_domain" "custom_domain" {
  count                    = var.enable_custom_domain ? 1 : 0
  name                     = "helloworld-custom"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.fd_profile.id
  host_name                = var.custom_domain_host_name

  tls {
    certificate_type = "ManagedCertificate"
  }
}

# The association is handled by the cdn_frontdoor_custom_domain_ids argument in the route resource.
