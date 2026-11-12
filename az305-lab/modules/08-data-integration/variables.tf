# =============================================================================
# AZ-305 Lab — Module 08: Data Integration — Input Variables
# =============================================================================
# Variables for Azure Data Factory, Data Lake Gen2, and supporting resources.
# Values without defaults must be provided via terraform.tfvars or CLI flags.
# =============================================================================

variable "location" {
  type        = string
  default     = "eastus"
  description = "Azure region for all resources. Should match foundation module region."
}

variable "prefix" {
  type        = string
  default     = "az305-lab"
  description = "Naming prefix for all resources. Keeps lab resources easily identifiable."
}

variable "foundation_resource_group_name" {
  type        = string
  description = "Name of the foundation resource group from Module 00."
}

variable "vnet_id" {
  type        = string
  description = "Resource ID of the hub VNet (from Module 00 outputs)."
}

variable "data_integration_subnet_id" {
  type        = string
  description = "Resource ID of the data-integration subnet (10.0.8.0/24) from Module 00."
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

variable "deploy_datalake_filesystems" {
  type        = bool
  default     = false
  description = "Create Data Lake Gen2 file systems (raw/processed/curated). Set true on initial deploy only. With public_network_access disabled by policy, Terraform cannot refresh these from outside the private network."
}

# --- Subscription profile variables (set by compatibility check) ---

variable "storage_shared_key_enabled" {
  type        = bool
  default     = true
  description = "Allow shared key access on storage accounts. Set false if subscription policy enforces Entra-only auth."
}

variable "storage_public_network_access" {
  type        = bool
  default     = true
  description = "Allow public network access to storage accounts. Set false if subscription policy enforces private-only."
}

variable "storage_allow_public_access" {
  type        = bool
  default     = true
  description = "Allow public blob access on storage accounts. Set false if subscription policy blocks it."
}

variable "data_factory_public_network" {
  type        = bool
  default     = true
  description = "Allow public network access to Data Factory. Set false if subscription policy enforces private-only."
}
