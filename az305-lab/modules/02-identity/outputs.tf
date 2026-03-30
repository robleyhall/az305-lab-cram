# =============================================================================
# AZ-305 Lab — Module 02: Identity & Access — Outputs
# =============================================================================
# These outputs are consumed by downstream modules that need to reference
# the identity objects created here (e.g., assigning managed identities to
# compute resources, granting Key Vault access to groups, etc.).
# =============================================================================

output "resource_group_name" {
  description = "Name of the identity module's resource group"
  value       = azurerm_resource_group.identity.name
}

output "admin_group_id" {
  description = "Object ID of the az305-lab-admins Entra ID security group"
  value       = azuread_group.admins.object_id
}

output "developer_group_id" {
  description = "Object ID of the az305-lab-developers Entra ID security group"
  value       = azuread_group.developers.object_id
}

output "reader_group_id" {
  description = "Object ID of the az305-lab-readers Entra ID security group"
  value       = azuread_group.readers.object_id
}

output "app_registration_id" {
  description = "Application (client) ID of the lab app registration"
  value       = azuread_application.lab_app.client_id
}

output "service_principal_id" {
  description = "Object ID of the lab app's service principal"
  value       = azuread_service_principal.lab_app.object_id
}

output "user_assigned_identity_id" {
  description = "Resource ID of the user-assigned managed identity (for use by other modules)"
  value       = azurerm_user_assigned_identity.lab_identity.id
}

output "user_assigned_identity_principal_id" {
  description = "Principal (object) ID of the user-assigned managed identity"
  value       = azurerm_user_assigned_identity.lab_identity.principal_id
}
