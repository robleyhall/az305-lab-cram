# =============================================================================
# AZ-305 Lab — Module 09: Compute Solutions — Input Variables
# =============================================================================

variable "location" {
  type        = string
  default     = "eastus"
  description = "Azure region for all compute resources. Should match foundation module region."
}

variable "prefix" {
  type        = string
  default     = "az305-lab"
  description = "Naming prefix for all resources. Keeps lab resources easily identifiable."
}

variable "foundation_resource_group_name" {
  type        = string
  description = "Name of the foundation resource group from module 00. Used as a data source reference."
}

variable "vnet_id" {
  type        = string
  description = "Resource ID of the shared virtual network from module 00."
}

variable "compute_subnet_id" {
  type        = string
  description = "Resource ID of the compute subnet (10.0.5.0/24) from module 00 subnet_ids[\"compute\"]."
}

variable "log_analytics_workspace_id" {
  type        = string
  description = "Resource ID of the centralized Log Analytics workspace from module 00."
}

variable "admin_ssh_public_key" {
  type        = string
  default     = ""
  description = "SSH public key for VM admin access. If empty, a key pair is auto-generated using tls_private_key."
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
