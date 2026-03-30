# =============================================================================
# AZ-305 Lab — Module 04: Monitoring & Alerting — Variables
# =============================================================================

variable "location" {
  type        = string
  description = "Azure region for all resources in this module."
  default     = "eastus"
}

variable "prefix" {
  type        = string
  description = "Naming prefix applied to all resources (e.g., 'az305-lab')."
  default     = "az305-lab"
}

variable "foundation_resource_group_name" {
  type        = string
  description = "Name of the foundation resource group (from Module 00 outputs)."
}

variable "log_analytics_workspace_id" {
  type        = string
  description = "Resource ID of the centralized Log Analytics workspace (from Module 00 outputs)."
}

variable "alert_email" {
  type        = string
  description = "Email address for alert notifications via the action group."
  default     = "admin@example.com"
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to all resources. Module-specific tags are merged automatically."
  default = {
    Lab        = "AZ-305"
    CostCenter = "CertStudy"
    ManagedBy  = "Terraform"
  }
}
