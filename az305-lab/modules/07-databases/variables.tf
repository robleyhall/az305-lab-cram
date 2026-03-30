# =============================================================================
# AZ-305 Lab — Module 07: Database Solutions — Input Variables
# =============================================================================

variable "location" {
  type        = string
  default     = "eastus"
  description = "Azure region for all database resources. Must match the foundation module's region."
}

variable "prefix" {
  type        = string
  default     = "az305-lab"
  description = "Naming prefix for all resources. Keeps lab resources easily identifiable."
}

variable "foundation_resource_group_name" {
  type        = string
  description = "Name of the foundation resource group (from Module 00 outputs)."
}

variable "vnet_id" {
  type        = string
  description = "Resource ID of the shared virtual network (from Module 00 outputs)."
}

variable "database_subnet_id" {
  type        = string
  description = "Resource ID of the database subnet (from Module 00 subnet_ids[\"database\"])."
}

variable "log_analytics_workspace_id" {
  type        = string
  description = "Resource ID of the centralized Log Analytics workspace (from Module 00 outputs)."
}

variable "sql_admin_username" {
  type        = string
  default     = "sqladmin"
  description = "Administrator login for the Azure SQL Server. Password is auto-generated via random_password."
}

variable "allowed_client_ip" {
  type        = string
  default     = "0.0.0.0"
  description = "Public IP address of the lab client for SQL Server firewall access. Set to your current IP for SSMS / Azure Data Studio connectivity."
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
