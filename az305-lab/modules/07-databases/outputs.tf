# =============================================================================
# AZ-305 Lab — Module 07: Database Solutions — Outputs
# =============================================================================
# These outputs are consumed by downstream modules and used to verify
# deployment. Use `terraform output` to retrieve values after apply.
# =============================================================================

# --- Resource Group ---

output "resource_group_name" {
  description = "Name of the databases resource group"
  value       = azurerm_resource_group.databases.name
}

# --- Azure SQL Server ---

output "sql_server_name" {
  description = "Name of the Azure SQL Server (globally unique)"
  value       = azurerm_mssql_server.main.name
}

output "sql_server_fqdn" {
  description = "Fully qualified domain name of the SQL Server (<name>.database.windows.net)"
  value       = azurerm_mssql_server.main.fully_qualified_domain_name
}

# --- Azure SQL Databases ---

output "sql_database_names" {
  description = "Names of the Azure SQL databases deployed (Basic DTU + Serverless vCore)"
  value       = [azurerm_mssql_database.basic.name, azurerm_mssql_database.serverless.name]
}

# --- Elastic Pool ---

output "elastic_pool_name" {
  description = "Name of the Azure SQL Elastic Pool"
  value       = azurerm_mssql_elasticpool.main.name
}

# --- Cosmos DB ---

output "cosmos_account_name" {
  description = "Name of the Azure Cosmos DB account (globally unique)"
  value       = azurerm_cosmosdb_account.main.name
}

output "cosmos_endpoint" {
  description = "Endpoint URI for the Cosmos DB account (https://<name>.documents.azure.com:443/)"
  value       = azurerm_cosmosdb_account.main.endpoint
}

output "cosmos_database_name" {
  description = "Name of the Cosmos DB SQL database"
  value       = azurerm_cosmosdb_sql_database.main.name
}

# --- Private Endpoint ---
# Disabled: private endpoint not deployed (cross-region deployment)
# output "private_endpoint_ip" {
#   description = "Private IP address assigned to the SQL Server private endpoint"
#   value       = azurerm_private_endpoint.sql.private_service_connection[0].private_ip_address
# }
