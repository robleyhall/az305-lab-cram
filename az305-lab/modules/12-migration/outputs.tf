# =============================================================================
# MODULE 12 — MIGRATION — Outputs
# =============================================================================

# --- Resource Group ---

output "resource_group_name" {
  description = "Name of the migration resource group"
  value       = azurerm_resource_group.migration.name
}

# --- Azure Migrate ---

output "migrate_project_name" {
  description = "Name of the Azure Migrate project (hub for discovery, assessment, and migration)"
  value       = azapi_resource.migrate_project.name
}

# --- Recovery Services Vault (ASR) ---

output "recovery_vault_name" {
  description = "Name of the Recovery Services Vault used for Azure Site Recovery migration"
  value       = azurerm_recovery_services_vault.migration.name
}

# --- Database Migration Service ---

output "dms_name" {
  description = "Name of the Database Migration Service instance"
  value       = azapi_resource.dms.name
}

# --- Staging Storage ---

output "staging_storage_account_name" {
  description = "Name of the storage account used for migration staging data"
  value       = azurerm_storage_account.migration_staging.name
}

# --- Simulated On-Premises VM ---

output "simulated_vm_ip" {
  description = "Private IP address of the simulated on-premises VM (nginx web server)"
  value       = azurerm_network_interface.onprem_sim.private_ip_address
}

# --- SSH Key ---

output "ssh_private_key" {
  description = "Generated SSH private key for the simulated VM (sensitive — lab use only)"
  value       = tls_private_key.ssh.private_key_pem
  sensitive   = true
}
