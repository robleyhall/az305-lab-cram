# =============================================================================
# AZ-305 Lab — Module 06: Storage Solutions — Outputs
# =============================================================================

# --- Resource Group ---

output "resource_group_name" {
  description = "Name of the storage module resource group."
  value       = azurerm_resource_group.storage.name
}

# --- Primary Storage Account (GPv2 / GRS) ---

output "storage_account_name" {
  description = "Name of the primary GPv2 storage account (globally unique)."
  value       = azurerm_storage_account.main.name
}

output "storage_account_id" {
  description = "Resource ID of the primary GPv2 storage account."
  value       = azurerm_storage_account.main.id
}

output "primary_blob_endpoint" {
  description = "Primary blob endpoint URL for the main storage account."
  value       = azurerm_storage_account.main.primary_blob_endpoint
}

output "primary_file_endpoint" {
  description = "Primary file endpoint URL for the main storage account."
  value       = azurerm_storage_account.main.primary_file_endpoint
}

# --- Data Lake Gen2 ---

output "datalake_account_name" {
  description = "Name of the Data Lake Storage Gen2 account."
  value       = azurerm_storage_account.datalake.name
}

output "datalake_account_id" {
  description = "Resource ID of the Data Lake Storage Gen2 account."
  value       = azurerm_storage_account.datalake.id
}

# --- Premium Block Blob ---

output "premium_blob_account_name" {
  description = "Name of the Premium Block Blob storage account."
  value       = azurerm_storage_account.premium_blob.name
}

# --- Managed Disks ---

output "managed_disk_ids" {
  description = "Map of managed disk names to their resource IDs."
  value = {
    standard = azurerm_managed_disk.standard.id
    premium  = azurerm_managed_disk.premium.id
  }
}

# --- Private Endpoint ---

output "private_endpoint_ip" {
  description = "Private IP address assigned to the storage blob private endpoint."
  value       = azurerm_private_endpoint.blob.private_service_connection[0].private_ip_address
}
