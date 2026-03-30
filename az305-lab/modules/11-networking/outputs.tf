# =============================================================================
# AZ-305 Lab — Module 11: Networking — Outputs
# =============================================================================

output "resource_group_name" {
  description = "Name of the networking resource group"
  value       = azurerm_resource_group.networking.name
}

output "secondary_vnet_id" {
  description = "Resource ID of the secondary virtual network"
  value       = azurerm_virtual_network.secondary.id
}

output "secondary_vnet_name" {
  description = "Name of the secondary virtual network"
  value       = azurerm_virtual_network.secondary.name
}

output "nsg_id" {
  description = "Resource ID of the web network security group"
  value       = azurerm_network_security_group.web.id
}

output "route_table_id" {
  description = "Resource ID of the custom route table"
  value       = azurerm_route_table.custom.id
}

output "dns_zone_name" {
  description = "Name of the private DNS zone"
  value       = azurerm_private_dns_zone.lab.name
}

output "public_ip_address" {
  description = "Static public IP address for networking resources"
  value       = azurerm_public_ip.networking.ip_address
}
