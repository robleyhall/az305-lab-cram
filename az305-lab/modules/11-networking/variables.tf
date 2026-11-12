# =============================================================================
# AZ-305 Lab — Module 11: Networking — Input Variables
# =============================================================================

variable "location" {
  type        = string
  default     = "eastus"
  description = "Azure region for all networking resources."
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

variable "foundation_vnet_id" {
  type        = string
  description = "Resource ID of the foundation virtual network (from Module 00 outputs)."
}

variable "foundation_vnet_name" {
  type        = string
  description = "Name of the foundation virtual network (from Module 00 outputs)."
}

variable "gateway_subnet_id" {
  type        = string
  description = "Resource ID of the GatewaySubnet (from Module 00 subnet_ids[\"GatewaySubnet\"])."
}

variable "bastion_subnet_id" {
  type        = string
  description = "Resource ID of the AzureBastionSubnet (from Module 00 subnet_ids[\"AzureBastionSubnet\"])."
}

variable "log_analytics_workspace_id" {
  type        = string
  description = "Resource ID of the centralized Log Analytics workspace (from Module 00 outputs)."
}

variable "allowed_ssh_ip" {
  type        = string
  default     = "0.0.0.0/0"
  description = "CIDR block allowed to SSH. Restrict to your IP in production (e.g., 203.0.113.50/32)."
}

variable "deploy_firewall" {
  type        = bool
  default     = false
  description = "Deploy Azure Firewall? WARNING: ~$30/day. Set to true only if cost is acceptable."
}

variable "deploy_vpn_gateway" {
  type        = bool
  default     = false
  description = "Deploy VPN Gateway? WARNING: ~$3/day. Deployment takes 30–45 minutes. Set to true only if cost is acceptable."
}

variable "deploy_bastion" {
  type        = bool
  default     = false
  description = "Deploy Azure Bastion? WARNING: ~$5/day. Set to true only if cost is acceptable."
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
