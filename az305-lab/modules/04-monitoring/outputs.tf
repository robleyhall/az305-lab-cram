# =============================================================================
# AZ-305 Lab — Module 04: Monitoring & Alerting — Outputs
# =============================================================================
# These outputs are consumed by downstream modules that need to send telemetry
# to Application Insights or reference the shared action group for alerts.
# =============================================================================

# --- Resource Group ---

output "resource_group_name" {
  description = "Name of the monitoring resource group"
  value       = azurerm_resource_group.monitoring.name
}

# --- Application Insights ---

output "application_insights_id" {
  description = "Resource ID of the Application Insights instance"
  value       = azurerm_application_insights.main.id
}

output "application_insights_instrumentation_key" {
  description = "Instrumentation key for Application Insights (legacy SDKs — prefer connection string)"
  value       = azurerm_application_insights.main.instrumentation_key
  sensitive   = true
}

output "application_insights_connection_string" {
  description = "Connection string for Application Insights (preferred authentication method)"
  value       = azurerm_application_insights.main.connection_string
  sensitive   = true
}

# --- Action Group ---

output "action_group_id" {
  description = "Resource ID of the monitoring action group (reusable across alert rules)"
  value       = azurerm_monitor_action_group.alerts.id
}
