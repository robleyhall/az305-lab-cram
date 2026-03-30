# =============================================================================
# AZ-305 Lab — Module 08: Data Integration — Outputs
# =============================================================================
# These outputs are consumed by downstream modules (e.g., 10-app-architecture)
# and by operators verifying the deployment.
# =============================================================================

# --- Resource Group ---

output "resource_group_name" {
  description = "Name of the data integration resource group"
  value       = azurerm_resource_group.main.name
}

# --- Azure Data Factory ---

output "data_factory_name" {
  description = "Name of the Azure Data Factory instance"
  value       = azurerm_data_factory.main.name
}

output "data_factory_id" {
  description = "Resource ID of the Azure Data Factory instance"
  value       = azurerm_data_factory.main.id
}

# --- Data Lake Storage Gen2 ---

output "datalake_account_name" {
  description = "Name of the Data Lake Storage Gen2 account"
  value       = azurerm_storage_account.datalake.name
}

output "datalake_account_id" {
  description = "Resource ID of the Data Lake Storage Gen2 account"
  value       = azurerm_storage_account.datalake.id
}

output "datalake_primary_dfs_endpoint" {
  description = "Primary DFS (Data Lake) endpoint URL — used by Spark, ADF, and Synapse"
  value       = azurerm_storage_account.datalake.primary_dfs_endpoint
}
