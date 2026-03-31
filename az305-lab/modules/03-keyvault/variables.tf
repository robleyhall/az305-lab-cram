# =============================================================================
# AZ-305 Lab — Module 03: Key Vault & Application Identity — Input Variables
# =============================================================================

variable "location" {
  type        = string
  default     = "eastus"
  description = "Azure region for all Key Vault resources."
}

variable "prefix" {
  type        = string
  default     = "az305-lab"
  description = "Naming prefix for all resources. Must be short — Key Vault names have a 24-char limit."
}

variable "foundation_resource_group_name" {
  type        = string
  description = "Name of the foundation resource group (from Module 00 outputs)."
}

variable "vnet_id" {
  type        = string
  description = "Resource ID of the shared virtual network (from Module 00 outputs)."
}

variable "keyvault_subnet_id" {
  type        = string
  description = "Resource ID of the Key Vault subnet (from Module 00 subnet_ids[\"keyvault\"])."
}

variable "log_analytics_workspace_id" {
  type        = string
  description = "Resource ID of the centralized Log Analytics workspace (from Module 00 outputs)."
}

variable "tags" {
  type        = map(string)
  description = "Default tags applied to every resource. Module-specific tags are merged on top."
  default = {
    Lab        = "AZ-305"
    CostCenter = "CertStudy"
    ManagedBy  = "Terraform"
  }
}

variable "deploy_kv_data_plane" {
  type        = bool
  default     = false
  description = "Create Key Vault data plane objects (secret, key, certificate). Set true on initial deploy only. With public_network_access disabled by policy, Terraform cannot refresh these from outside the private network on subsequent plans."
}

# --- Subscription profile variables (set by compatibility check) ---

variable "keyvault_public_network_access" {
  type        = bool
  default     = true
  description = "Allow public network access to Key Vault. Set false if subscription policy enforces private-only access."
}
