# =============================================================================
# AZ-305 Lab — Module 10: Application Architecture — Outputs
# =============================================================================

# --- Resource Group ---

output "resource_group_name" {
  description = "Name of the app architecture resource group"
  value       = azurerm_resource_group.apparch.name
}

# --- Event Grid ---

output "event_grid_topic_endpoint" {
  description = "Endpoint URL of the Event Grid topic for publishing events"
  value       = azurerm_eventgrid_topic.main.endpoint
}

# --- Event Hubs ---

output "event_hubs_namespace_name" {
  description = "Name of the Event Hubs namespace (globally unique)"
  value       = azurerm_eventhub_namespace.main.name
}

# --- Service Bus ---

output "service_bus_namespace_name" {
  description = "Name of the Service Bus namespace (globally unique)"
  value       = azurerm_servicebus_namespace.main.name
}

# --- API Management ---

output "apim_gateway_url" {
  description = "Gateway URL of the API Management instance"
  value       = azurerm_api_management.main.gateway_url
}

output "apim_name" {
  description = "Name of the API Management instance (globally unique)"
  value       = azurerm_api_management.main.name
}

# --- Redis Cache ---

output "redis_hostname" {
  description = "Hostname of the Azure Cache for Redis instance"
  value       = azurerm_redis_cache.main.hostname
}

output "redis_port" {
  description = "SSL port of the Azure Cache for Redis instance"
  value       = azurerm_redis_cache.main.ssl_port
}
