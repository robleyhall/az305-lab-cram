# =============================================================================
# AZ-305 Lab — Module 00: Foundation
# =============================================================================
# Shared infrastructure that every other lab module depends on.
# Creates: resource group, virtual network with preallocated subnets,
# default NSG, and a centralized Log Analytics workspace.
# =============================================================================

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "azurerm" {
  features {}
}

# -----------------------------------------------------------------------------
# Local values — merge caller-supplied tags with module-level defaults
# -----------------------------------------------------------------------------
locals {
  # Merge user-provided tags with module-specific tags so every resource
  # carries a consistent label set for cost tracking and governance labs.
  common_tags = merge(var.tags, {
    Module  = "00-foundation"
    Purpose = "Shared foundation resources"
  })
}

# -----------------------------------------------------------------------------
# Random suffix — ensures globally unique resource names across deployments
# -----------------------------------------------------------------------------
# Azure resource names for Log Analytics, VNets, etc. must be unique within
# their scope. A short random suffix avoids collisions when multiple students
# deploy the same lab in the same subscription.
resource "random_string" "suffix" {
  length  = 6
  upper   = false
  special = false
}

# -----------------------------------------------------------------------------
# Resource Group — single group that holds all foundation resources
# -----------------------------------------------------------------------------
# Every lab module creates its own resource group, but the foundation RG also
# holds shared networking and monitoring resources consumed by all modules.
resource "azurerm_resource_group" "foundation" {
  name     = "${var.prefix}-mod00-foundation-rg-${random_string.suffix.result}"
  location = var.location
  tags     = local.common_tags

  lifecycle {
    # Non-semantic: Azure auto-adds rg-class tag for internal classification. Not a config choice.
    ignore_changes = [tags["rg-class"]]
  }
}

# -----------------------------------------------------------------------------
# Virtual Network — shared VNet with preallocated subnets for all modules
# -----------------------------------------------------------------------------
# A single /16 address space is carved into /24 subnets so that each lab
# module gets its own IP range without overlapping. This mirrors a real-world
# hub-spoke design where the hub VNet is provisioned up-front.
resource "azurerm_virtual_network" "main" {
  name                = "${var.prefix}-vnet-${random_string.suffix.result}"
  location            = azurerm_resource_group.foundation.location
  resource_group_name = azurerm_resource_group.foundation.name
  address_space       = ["10.0.0.0/16"]
  tags                = local.common_tags
}

# -----------------------------------------------------------------------------
# Subnets — one per lab module, plus Azure-reserved names for Bastion & GW
# -----------------------------------------------------------------------------
# Each subnet is preallocated so downstream modules can reference them by
# output without needing to manage CIDR math themselves.

# Default subnet for foundation-level resources (jump boxes, test VMs, etc.)
resource "azurerm_subnet" "default" {
  name                 = "default"
  resource_group_name  = azurerm_resource_group.foundation.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.0.0/24"]
}

# Governance module — Azure Policy, Management Groups, Blueprints demos
resource "azurerm_subnet" "governance" {
  name                 = "governance"
  resource_group_name  = azurerm_resource_group.foundation.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Identity module — Entra ID, RBAC, Managed Identities, Conditional Access
resource "azurerm_subnet" "identity" {
  name                 = "identity"
  resource_group_name  = azurerm_resource_group.foundation.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.2.0/24"]
}

# Key Vault module — secrets, keys, certificates, RBAC access policies
resource "azurerm_subnet" "keyvault" {
  name                 = "keyvault"
  resource_group_name  = azurerm_resource_group.foundation.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.3.0/24"]
  service_endpoints    = ["Microsoft.KeyVault"]
}

# Monitoring module — Azure Monitor, alerts, diagnostic settings
resource "azurerm_subnet" "monitoring" {
  name                 = "monitoring"
  resource_group_name  = azurerm_resource_group.foundation.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.4.0/24"]
}

# Compute module — VMs, VMSS, availability sets, proximity placement groups
resource "azurerm_subnet" "compute" {
  name                 = "compute"
  resource_group_name  = azurerm_resource_group.foundation.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.5.0/24"]
}

# Storage module — Blob, Files, queues, tables, redundancy tiers
resource "azurerm_subnet" "storage" {
  name                 = "storage"
  resource_group_name  = azurerm_resource_group.foundation.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.6.0/24"]
  service_endpoints    = ["Microsoft.Storage"]
}

# Database module — SQL, Cosmos DB, MySQL, PostgreSQL
resource "azurerm_subnet" "database" {
  name                 = "database"
  resource_group_name  = azurerm_resource_group.foundation.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.7.0/24"]
  service_endpoints    = ["Microsoft.Sql"]
}

# Data Integration module — Data Factory, Event Hub, Service Bus
resource "azurerm_subnet" "data_integration" {
  name                 = "data-integration"
  resource_group_name  = azurerm_resource_group.foundation.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.8.0/24"]
}

# App Architecture module — App Service, Functions, Container Apps, AKS
resource "azurerm_subnet" "app_architecture" {
  name                 = "app-architecture"
  resource_group_name  = azurerm_resource_group.foundation.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.9.0/24"]
}

# Networking module — Load Balancers, Application Gateway, Front Door, DNS
resource "azurerm_subnet" "networking" {
  name                 = "networking"
  resource_group_name  = azurerm_resource_group.foundation.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.10.0/24"]
}

# Migration module — Azure Migrate, Database Migration Service
resource "azurerm_subnet" "migration" {
  name                 = "migration"
  resource_group_name  = azurerm_resource_group.foundation.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.11.0/24"]
}

# Azure Bastion requires a subnet with this exact name.
# Used for secure RDP/SSH access without public IPs on target VMs.
resource "azurerm_subnet" "bastion" {
  name                 = "AzureBastionSubnet"
  resource_group_name  = azurerm_resource_group.foundation.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.250.0/24"]
}

# Azure VPN Gateway requires a subnet with this exact name.
# Used for site-to-site and point-to-site VPN connectivity labs.
resource "azurerm_subnet" "gateway" {
  name                 = "GatewaySubnet"
  resource_group_name  = azurerm_resource_group.foundation.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.251.0/24"]
}

# -----------------------------------------------------------------------------
# Network Security Group — default rules for lab workloads
# -----------------------------------------------------------------------------
# Provides a baseline NSG that downstream modules can associate with their
# subnets. Allows outbound internet (for package installs, etc.) and permits
# intra-VNet traffic while blocking unsolicited inbound from the internet.
resource "azurerm_network_security_group" "default" {
  name                = "${var.prefix}-default-nsg-${random_string.suffix.result}"
  location            = azurerm_resource_group.foundation.location
  resource_group_name = azurerm_resource_group.foundation.name
  tags                = local.common_tags

  # Allow all traffic originating from within the virtual network.
  # This enables inter-module communication across subnets.
  security_rule {
    name                       = "AllowVNetInbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "VirtualNetwork"
  }

  # Deny all other inbound traffic from the internet.
  # Individual modules can add higher-priority rules to open specific ports.
  security_rule {
    name                       = "DenyInternetInbound"
    priority                   = 4000
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }

  # Allow all outbound traffic so lab VMs can reach the internet for
  # package updates, Azure APIs, and other dependencies.
  security_rule {
    name                       = "AllowAllOutbound"
    priority                   = 100
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# Associate the default NSG with the default subnet as a baseline.
# Other modules should create their own associations as needed.
resource "azurerm_subnet_network_security_group_association" "default" {
  subnet_id                 = azurerm_subnet.default.id
  network_security_group_id = azurerm_network_security_group.default.id
}

# -----------------------------------------------------------------------------
# Log Analytics Workspace — centralized logging for all lab modules
# -----------------------------------------------------------------------------
# Every module sends diagnostic logs here. PerGB2018 is the only current
# pricing tier. 30-day retention keeps costs low while giving enough history
# for monitoring and troubleshooting labs.
resource "azurerm_log_analytics_workspace" "main" {
  name                = "${var.prefix}-law-${random_string.suffix.result}"
  location            = azurerm_resource_group.foundation.location
  resource_group_name = azurerm_resource_group.foundation.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = local.common_tags
}
