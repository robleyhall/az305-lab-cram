# =============================================================================
# AZ-305 Lab — Module 03: Key Vault & Application Identity — Outputs
# =============================================================================
# These outputs are consumed by downstream modules that need to store secrets,
# retrieve encryption keys, or authenticate using the managed identity.
# =============================================================================

# --- Resource Group ---

output "resource_group_name" {
  description = "Name of the Key Vault module resource group"
  value       = azurerm_resource_group.keyvault.name
}

# --- Key Vault ---

output "key_vault_id" {
  description = "Resource ID of the Key Vault"
  value       = azurerm_key_vault.main.id
}

output "key_vault_name" {
  description = "Name of the Key Vault (globally unique)"
  value       = azurerm_key_vault.main.name
}

output "key_vault_uri" {
  description = "URI of the Key Vault (https://<name>.vault.azure.net/)"
  value       = azurerm_key_vault.main.vault_uri
}

# --- Managed Identity ---

output "managed_identity_id" {
  description = "Resource ID of the user-assigned managed identity"
  value       = azurerm_user_assigned_identity.main.id
}

output "managed_identity_principal_id" {
  description = "Object (principal) ID of the managed identity — used in role assignments"
  value       = azurerm_user_assigned_identity.main.principal_id
}

output "managed_identity_client_id" {
  description = "Client (application) ID of the managed identity — used in app configuration"
  value       = azurerm_user_assigned_identity.main.client_id
}

# --- Private Endpoint ---

output "private_endpoint_ip" {
  description = "Private IP address assigned to the Key Vault private endpoint"
  value       = azurerm_private_endpoint.keyvault.private_service_connection[0].private_ip_address
}
