# =============================================================================
# AZ-305 Lab — Module 10: Application Architecture — Variables
# =============================================================================

variable "location" {
  type        = string
  default     = "eastus"
  description = "Azure region for all app architecture resources. Must support Event Hubs, Service Bus, APIM Consumption, and Redis."
}

variable "prefix" {
  type        = string
  default     = "az305-lab"
  description = "Naming prefix for all resources. Keep it short (6-10 chars) to stay within Azure name-length limits."
}

variable "foundation_resource_group_name" {
  type        = string
  default     = ""
  description = "Name of the foundation resource group (Module 00). Used for reference only in this module."
}

variable "log_analytics_workspace_id" {
  type        = string
  default     = ""
  description = "Resource ID of the Log Analytics workspace from Module 00. Required for diagnostic settings on Event Hubs, Service Bus, and APIM."
}

variable "apim_publisher_name" {
  type        = string
  default     = "AZ-305 Lab"
  description = "Publisher name displayed in the API Management developer portal."
}

variable "apim_publisher_email" {
  type        = string
  default     = "admin@example.com"
  description = "Publisher email for API Management notifications and developer portal contact."
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
