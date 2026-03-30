# =============================================================================
# MODULE 12 — MIGRATION — Variables
# =============================================================================

variable "location" {
  type        = string
  default     = "eastus"
  description = "Azure region for all migration resources."
}

variable "prefix" {
  type        = string
  default     = "az305-lab"
  description = "Naming prefix for all resources. Keeps lab resources easily identifiable."
}

variable "foundation_resource_group_name" {
  type        = string
  default     = "az305-lab-foundation-rg"
  description = "Name of the foundation resource group (from Module 00). Used for referencing shared infrastructure."
}

variable "vnet_id" {
  type        = string
  description = "Resource ID of the shared VNet from the foundation module."
}

variable "migration_subnet_id" {
  type        = string
  description = "Resource ID of the migration subnet (10.0.11.0/24) for DMS and the simulated on-premises VM."
}

variable "log_analytics_workspace_id" {
  type        = string
  description = "Resource ID of the Log Analytics workspace (from Module 00/04) for diagnostic settings."
}

variable "admin_ssh_public_key" {
  type        = string
  default     = ""
  description = "Optional SSH public key for VM access. If empty, a key pair is auto-generated via tls_private_key (see outputs for the private key)."
}

variable "auto_shutdown_time" {
  type        = string
  default     = "2200"
  description = "Daily auto-shutdown time in HHMM format (UTC). Default 22:00 UTC."
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
