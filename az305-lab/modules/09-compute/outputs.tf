# =============================================================================
# AZ-305 Lab — Module 09: Compute Solutions — Outputs
# =============================================================================
# These outputs are consumed by downstream modules or exercises to reference
# compute resources created by this module.
# =============================================================================

# --- Resource Group ---

output "resource_group_name" {
  description = "Name of the compute module resource group"
  value       = azurerm_resource_group.compute.name
}

# --- Virtual Machine ---

output "vm_id" {
  description = "Resource ID of the Linux virtual machine"
  value       = azurerm_linux_virtual_machine.main.id
}

output "vm_private_ip" {
  description = "Private IP address of the Linux VM on the compute subnet (10.0.5.0/24)"
  value       = azurerm_network_interface.vm.private_ip_address
}

# --- App Service / Web App ---

output "webapp_url" {
  description = "Default HTTPS URL of the web app"
  value       = "https://${azurerm_linux_web_app.main.default_hostname}"
}

output "webapp_name" {
  description = "Name of the web app (used for az webapp deploy commands)"
  value       = azurerm_linux_web_app.main.name
}

# --- Azure Container Instance ---

output "aci_ip_address" {
  description = "Public IP address of the ACI container group running nginx"
  value       = azurerm_container_group.main.ip_address
}

# --- Azure Container Registry ---

output "acr_login_server" {
  description = "Login server URL for the Azure Container Registry (e.g., az305-labacr123456.azurecr.io)"
  value       = azurerm_container_registry.main.login_server
}

# --- Azure Function App ---

output "function_app_url" {
  description = "Default HTTPS URL of the Function App"
  value       = "https://${azurerm_linux_function_app.main.default_hostname}"
}

output "function_app_name" {
  description = "Name of the Function App (used for func azure functionapp publish)"
  value       = azurerm_linux_function_app.main.name
}

# --- Azure Batch ---

output "batch_account_name" {
  description = "Name of the Azure Batch account"
  value       = azurerm_batch_account.main.name
}

# --- SSH Key (for lab convenience) ---

output "ssh_private_key_pem" {
  description = "Generated SSH private key in PEM format (sensitive — use for lab VM access only)"
  value       = tls_private_key.ssh.private_key_pem
  sensitive   = true
}
