variable "location" {
  default = "East US"
}

variable "resource_group_name" {
  default = "static-frontdoor-rg"
}

variable "app_name" {
  default = "helloworldstacticapp"
}

variable "subscription_id" {
  description = "The Azure Subscription ID where resources will be created"
  type        = string
  
}

variable "tenant_id" {
  description = "The Azure Tenant ID for authentication"
  type        = string
}

#This is for custom domain
variable "enable_custom_domain" {
  description = "Set to true to enable custom domain configuration"
  type        = bool
  default     = false
}

variable "custom_domain_host_name" {
  description = "FQDN of the custom domain (e.g., helloworld.example.com)"
  type        = string
  default     = ""
}
