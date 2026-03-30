# =============================================================================
# AZ-305 Lab — Module 00: Foundation — Input Variables
# =============================================================================

variable "location" {
  type        = string
  default     = "eastus"
  description = "Azure region for all foundation resources. Choose a region close to you with AZ support."
}

variable "prefix" {
  type        = string
  default     = "az305-lab"
  description = "Naming prefix for all resources. Keeps lab resources easily identifiable."
}

variable "environment" {
  type        = string
  default     = "lab"
  description = "Environment label (lab, dev, staging). Used in tagging and naming conventions."
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
