# =============================================================================
# AZ-305 Lab — Module 06: Storage Solutions — Variables
# =============================================================================

variable "location" {
  type        = string
  default     = "eastus"
  description = "Azure region — must match foundation module region."
}

variable "prefix" {
  type        = string
  default     = "az305-lab"
  description = "Naming prefix for all resources."
}

variable "foundation_resource_group_name" {
  type        = string
  description = "Name of the foundation resource group (from Module 00 outputs)."
}

variable "vnet_id" {
  type        = string
  description = "Resource ID of the shared virtual network (from Module 00 outputs)."
}

variable "storage_subnet_id" {
  type        = string
  description = "Resource ID of the storage subnet (from Module 00 subnet_ids[\"storage\"])."
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
