# =============================================================================
# MODULE 05 — OUTPUTS
# =============================================================================

# --- Resource Group ---
output "resource_group_name" {
  description = "Name of the HA/DR resource group"
  value       = azurerm_resource_group.hadr.name
}

# --- Availability Set ---
output "availability_set_id" {
  description = "Resource ID of the availability set"
  value       = azurerm_availability_set.main.id
}

# --- Virtual Machines ---
output "vm_ids" {
  description = "Map of VM name to resource ID for all VMs in this module"
  value = merge(
    { for i, vm in azurerm_linux_virtual_machine.avset_vm : vm.name => vm.id },
    { (azurerm_linux_virtual_machine.az_vm.name) = azurerm_linux_virtual_machine.az_vm.id }
  )
}

# --- Load Balancers ---
output "public_lb_ip" {
  description = "Public IP address of the external load balancer"
  value       = azurerm_public_ip.lb.ip_address
}

output "internal_lb_ip" {
  description = "Private IP address of the internal load balancer"
  value       = azurerm_lb.internal.frontend_ip_configuration[0].private_ip_address
}

# --- Recovery Services Vault ---
output "recovery_vault_id" {
  description = "Resource ID of the Recovery Services Vault"
  value       = azurerm_recovery_services_vault.main.id
}

# --- Traffic Manager ---
output "traffic_manager_fqdn" {
  description = "FQDN of the Traffic Manager profile (DNS-based global load balancing)"
  value       = azurerm_traffic_manager_profile.main.fqdn
}

# --- SSH Key (for lab convenience) ---
output "ssh_private_key" {
  description = "Generated SSH private key for VM access (sensitive — use only in lab)"
  value       = tls_private_key.ssh.private_key_pem
  sensitive   = true
}
