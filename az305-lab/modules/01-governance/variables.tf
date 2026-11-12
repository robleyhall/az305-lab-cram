# =============================================================================
# AZ-305 Lab — Module 01: Governance & Compliance — Input Variables
# =============================================================================

variable "location" {
  type        = string
  default     = "eastus"
  description = "Azure region for governance resources. Should match foundation module region."
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

variable "tags" {
  type        = map(string)
  description = "Default tags applied to every resource. Module-specific tags are merged on top."
  default = {
    Lab        = "AZ-305"
    CostCenter = "CertStudy"
    ManagedBy  = "Terraform"
  }
}
