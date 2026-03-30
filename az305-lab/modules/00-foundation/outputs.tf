# =============================================================================
# AZ-305 Lab — Module 00: Foundation — Outputs
# =============================================================================
# These outputs are consumed by every downstream lab module to reference
# shared infrastructure without hard-coding names or IDs.
# =============================================================================

# --- Resource Group ---

output "resource_group_name" {
  description = "Name of the foundation resource group"
  value       = azurerm_resource_group.foundation.name
}

output "resource_group_id" {
  description = "Resource ID of the foundation resource group"
  value       = azurerm_resource_group.foundation.id
}

# --- Virtual Network ---

output "vnet_name" {
  description = "Name of the shared virtual network"
  value       = azurerm_virtual_network.main.name
}

output "vnet_id" {
  description = "Resource ID of the shared virtual network"
  value       = azurerm_virtual_network.main.id
}

# --- Subnets ---

output "subnet_ids" {
  description = "Map of subnet name to subnet resource ID for all preallocated subnets"
  value = {
    "default"            = azurerm_subnet.default.id
    "governance"         = azurerm_subnet.governance.id
    "identity"           = azurerm_subnet.identity.id
    "keyvault"           = azurerm_subnet.keyvault.id
    "monitoring"         = azurerm_subnet.monitoring.id
    "compute"            = azurerm_subnet.compute.id
    "storage"            = azurerm_subnet.storage.id
    "database"           = azurerm_subnet.database.id
    "data-integration"   = azurerm_subnet.data_integration.id
    "app-architecture"   = azurerm_subnet.app_architecture.id
    "networking"         = azurerm_subnet.networking.id
    "migration"          = azurerm_subnet.migration.id
    "AzureBastionSubnet" = azurerm_subnet.bastion.id
    "GatewaySubnet"      = azurerm_subnet.gateway.id
  }
}

# --- Log Analytics ---

output "log_analytics_workspace_id" {
  description = "Resource ID of the shared Log Analytics workspace"
  value       = azurerm_log_analytics_workspace.main.id
}

output "log_analytics_workspace_name" {
  description = "Name of the shared Log Analytics workspace"
  value       = azurerm_log_analytics_workspace.main.name
}

# --- Naming ---

output "random_suffix" {
  description = "Random 6-character suffix used for globally unique resource names"
  value       = random_string.suffix.result
}

# --- Network Security ---

output "nsg_id" {
  description = "Resource ID of the default network security group"
  value       = azurerm_network_security_group.default.id
}
