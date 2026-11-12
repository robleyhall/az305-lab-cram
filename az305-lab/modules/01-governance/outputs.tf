# =============================================================================
# AZ-305 Lab — Module 01: Governance & Compliance — Outputs
# =============================================================================
# Downstream modules or exercises can reference these to inspect governance
# resources created by this module.
# =============================================================================

output "resource_group_name" {
  description = "Name of the governance module resource group"
  value       = azurerm_resource_group.governance.name
}

output "resource_group_id" {
  description = "Resource ID of the governance resource group"
  value       = azurerm_resource_group.governance.id
}

output "policy_definition_ids" {
  description = "Map of custom policy definition names to their resource IDs"
  value = {
    "require-costcenter-tag" = azurerm_policy_definition.require_costcenter_tag.id
    "restrict-vm-skus"       = azurerm_policy_definition.restrict_vm_skus.id
  }
}

output "custom_role_id" {
  description = "Resource ID of the custom 'Lab Reader Plus' RBAC role definition"
  value       = azurerm_role_definition.lab_reader_plus.role_definition_resource_id
}

output "management_group_id" {
  description = "Resource ID of the lab management group (null if creation was skipped)"
  value       = try(azurerm_management_group.lab[0].id, null)
}
