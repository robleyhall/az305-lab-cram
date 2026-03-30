# =============================================================================
# MODULE 05 — VARIABLES
# =============================================================================

variable "location" {
  type        = string
  default     = "eastus"
  description = "Azure region. East US supports all HA/DR features including Availability Zones."
}

variable "prefix" {
  type        = string
  default     = "az305-lab"
  description = "Naming prefix for all resources. Used in resource names for easy identification."
}

variable "foundation_resource_group_name" {
  type        = string
  default     = "az305-lab-foundation-rg"
  description = "Name of the foundation resource group from module 00. Used to reference shared resources."
}

variable "vnet_id" {
  type        = string
  default     = ""
  description = "Resource ID of the foundation VNet. Used for network integration."
}

variable "compute_subnet_id" {
  type        = string
  default     = ""
  description = "Resource ID of the compute subnet (10.0.5.0/24) from the foundation VNet. VMs and internal LB are placed here."
}

variable "log_analytics_workspace_id" {
  type        = string
  default     = ""
  description = "Resource ID of the Log Analytics workspace from foundation module. Used for diagnostic settings."
}

variable "admin_ssh_public_key" {
  type        = string
  default     = ""
  description = "SSH public key for VM admin access. If empty, a key pair is auto-generated via tls_private_key."
}

variable "auto_shutdown_time" {
  type        = string
  default     = "2200"
  description = "Daily auto-shutdown time in HHMM format (UTC). Default 22:00 UTC. Keeps lab costs low."
}

variable "tags" {
  type        = map(string)
  default     = {
    Lab        = "AZ-305"
    CostCenter = "CertStudy"
    ManagedBy  = "Terraform"
  }
  description = "Default tags applied to every resource. Merged with module-specific tags."
}
