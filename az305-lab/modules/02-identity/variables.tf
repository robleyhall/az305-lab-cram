# =============================================================================
# AZ-305 Lab — Module 02: Identity & Access — Input Variables
# =============================================================================

variable "location" {
  type        = string
  default     = "eastus"
  description = "Azure region for the identity resource group. Entra ID objects are global but the RG needs a region."
}

variable "prefix" {
  type        = string
  default     = "az305-lab"
  description = "Naming prefix for all resources. Keeps lab resources easily identifiable."
}

variable "foundation_resource_group_name" {
  type        = string
  description = "Name of the foundation module's resource group. Used for cross-module references."
}

variable "log_analytics_workspace_id" {
  type        = string
  description = "Resource ID of the shared Log Analytics workspace from the foundation module. Used for Entra ID diagnostic settings."
}

variable "enable_conditional_access" {
  type        = bool
  default     = false
  description = "Deploy Conditional Access policies. Requires Entra ID P1+ licensing. Set to true only if your tenant has P1 or P2."
}

variable "enable_entra_diagnostics" {
  type        = bool
  default     = false
  description = "Deploy Entra ID diagnostic settings. Requires Security Administrator or Global Administrator Entra ID role."
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
