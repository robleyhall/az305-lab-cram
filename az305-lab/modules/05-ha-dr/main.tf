# =============================================================================
# MODULE 05 — HIGH AVAILABILITY & DISASTER RECOVERY
# =============================================================================
# AZ-305 Exam Domain: Design Business Continuity Solutions (15-20%)
#
# This module demonstrates:
#   - Availability Sets vs Availability Zones (CRITICAL exam topic)
#   - Public & Internal Load Balancers (Standard SKU)
#   - Recovery Services Vault & Azure Backup
#   - Traffic Manager for global DNS-based routing
#
# KEY EXAM CONCEPTS:
#   SLA Tiers:
#     - Single VM (Premium SSD): 99.9%
#     - Availability Set:         99.95%
#     - Availability Zones:       99.99%
#
#   Load Balancer Decision Tree:
#     ┌────────────────────┬──────────┬──────────┬─────────────────────────┐
#     │ Service            │ Layer    │ Scope    │ Key Feature             │
#     ├────────────────────┼──────────┼──────────┼─────────────────────────┤
#     │ Azure Load Balancer│ L4 (TCP) │ Regional │ HA ports, zone-redundant│
#     │ Application Gateway│ L7 (HTTP)│ Regional │ WAF, SSL offload, path  │
#     │ Traffic Manager    │ DNS      │ Global   │ DNS-based, any endpoint │
#     │ Azure Front Door   │ L7 (HTTP)│ Global   │ WAF + CDN + acceleration│
#     └────────────────────┴──────────┴──────────┴─────────────────────────┘
#
#   RPO vs RTO:
#     - RPO (Recovery Point Objective): Maximum acceptable data loss (time)
#     - RTO (Recovery Time Objective): Maximum acceptable downtime
#     - Azure Backup: RPO ~ 24h (daily), RTO ~ hours
#     - Azure Site Recovery: RPO ~ seconds-minutes, RTO ~ minutes
#
#   Paired Regions:
#     - Azure pairs regions 300+ miles apart for DR (e.g., East US ↔ West US)
#     - Some services replicate automatically to paired region (GRS storage)
#     - Recovery Services Vault with GRS replicates to paired region
#
#   Azure Site Recovery (ASR):
#     - Replicates VMs to a secondary region continuously
#     - Automated failover with recovery plans
#     - Not deployed here (requires two regions), but critical exam topic
#     - Use when RTO/RPO must be minutes, not hours
# =============================================================================

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "azurerm" {
  features {
    recovery_services_vaults {
      recover_soft_deleted_backup_protected_vm = true
    }
  }
}

# =============================================================================
# COMMON RESOURCES
# =============================================================================

resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

locals {
  common_tags = merge(var.tags, {
    Module  = "05-ha-dr"
    Purpose = "High Availability & Disaster Recovery"
  })
  suffix = random_string.suffix.result
}

resource "azurerm_resource_group" "hadr" {
  name     = "${var.prefix}-hadr-rg-${local.suffix}"
  location = var.location
  tags     = local.common_tags
}

# =============================================================================
# SSH KEY GENERATION
# =============================================================================
# Self-contained: generates an SSH key pair so the module works without
# requiring the user to supply one. In production, use a pre-existing key
# stored in Key Vault.
# =============================================================================

resource "tls_private_key" "ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# =============================================================================
# AVAILABILITY SET
# =============================================================================
# EXAM TOPIC: Availability Sets vs Availability Zones
#
# Availability Set:
#   - Distributes VMs across Fault Domains (FDs) and Update Domains (UDs)
#   - Fault Domain  = separate power + network switch (rack-level isolation)
#   - Update Domain = group of VMs that reboot together during maintenance
#   - Max 3 FDs, max 20 UDs per set
#   - Protects against: rack failures, planned maintenance
#   - SLA: 99.95%
#   - Scope: single datacenter
#
# Availability Zone:
#   - Physically separate datacenter within an Azure region
#   - Independent power, cooling, networking
#   - Protects against: entire datacenter failure
#   - SLA: 99.99%
#   - Scope: region (across datacenters)
#
# CRITICAL: You CANNOT place a VM in both an Availability Set AND an
# Availability Zone. They are mutually exclusive. This is a common exam
# question!
#
# When to use which:
#   - Availability Set: legacy apps, lower cost, rack-level protection
#   - Availability Zone: mission-critical apps, highest SLA, datacenter-level
# =============================================================================

resource "azurerm_availability_set" "main" {
  name                         = "${var.prefix}-avset-${local.suffix}"
  location                     = azurerm_resource_group.hadr.location
  resource_group_name          = azurerm_resource_group.hadr.name
  platform_fault_domain_count  = 2  # Separate racks (power + network)
  platform_update_domain_count = 5  # Groups for rolling maintenance
  managed                      = true # Required for managed-disk VMs

  tags = local.common_tags
}

# =============================================================================
# NETWORK INTERFACES
# =============================================================================
# Each VM needs its own NIC. The avset VMs go into the compute subnet
# provided by the foundation module.
# =============================================================================

resource "azurerm_network_interface" "avset_vm" {
  count               = 2
  name                = "${var.prefix}-avset-vm-${count.index}-nic-${local.suffix}"
  location            = azurerm_resource_group.hadr.location
  resource_group_name = azurerm_resource_group.hadr.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = var.compute_subnet_id
    private_ip_address_allocation = "Dynamic"
  }

  tags = local.common_tags
}

resource "azurerm_network_interface" "az_vm" {
  name                = "${var.prefix}-az-vm-nic-${local.suffix}"
  location            = azurerm_resource_group.hadr.location
  resource_group_name = azurerm_resource_group.hadr.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = var.compute_subnet_id
    private_ip_address_allocation = "Dynamic"
  }

  tags = local.common_tags
}

# =============================================================================
# VMs IN AVAILABILITY SET
# =============================================================================
# Two VMs spread across fault domains and update domains within the avset.
# Standard_B1s is the cheapest burstable VM (1 vCPU, 1 GiB RAM).
# Auto-shutdown at 22:00 UTC keeps lab costs low.
# =============================================================================

resource "azurerm_linux_virtual_machine" "avset_vm" {
  count               = 2
  name                = "${var.prefix}-avset-vm-${count.index}-${local.suffix}"
  location            = azurerm_resource_group.hadr.location
  resource_group_name = azurerm_resource_group.hadr.name
  size                = "Standard_B1s"
  availability_set_id = azurerm_availability_set.main.id
  # NOTE: No `zone` parameter — Availability Set and Zone are mutually exclusive!

  admin_username                  = "azureuser"
  disable_password_authentication = true

  admin_ssh_key {
    username   = "azureuser"
    public_key = tls_private_key.ssh.public_key_openssh
  }

  network_interface_ids = [azurerm_network_interface.avset_vm[count.index].id]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS" # Lab cost savings; Premium_LRS for 99.9% single-VM SLA
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  tags = local.common_tags
}

# --- Auto-shutdown for avset VMs (cost control) ---
resource "azurerm_dev_test_global_vm_shutdown_schedule" "avset_vm" {
  count              = 2
  virtual_machine_id = azurerm_linux_virtual_machine.avset_vm[count.index].id
  location           = azurerm_resource_group.hadr.location
  enabled            = true

  daily_recurrence_time = var.auto_shutdown_time
  timezone              = "UTC"

  notification_settings {
    enabled = false
  }

  tags = local.common_tags
}

# =============================================================================
# VM IN AVAILABILITY ZONE
# =============================================================================
# Demonstrates zone-redundant deployment. This VM is in Zone 1.
#
# EXAM POINT: This VM is NOT in the availability set. You cannot combine
# availability sets and availability zones on the same VM. If the exam asks
# how to achieve 99.99% SLA, the answer is Availability Zones (not sets).
#
# Zone-redundant architecture:
#   - Deploy VMs across zones 1, 2, 3 for maximum resilience
#   - Use Standard Load Balancer (zone-redundant by default) in front
#   - Each zone is an independent datacenter with its own power/cooling
# =============================================================================

resource "azurerm_linux_virtual_machine" "az_vm" {
  name                = "${var.prefix}-az-vm-${local.suffix}"
  location            = azurerm_resource_group.hadr.location
  resource_group_name = azurerm_resource_group.hadr.name
  size                = "Standard_B1s"
  zone                = "1"
  # NOTE: No `availability_set_id` — Zone and Availability Set are mutually exclusive!

  admin_username                  = "azureuser"
  disable_password_authentication = true

  admin_ssh_key {
    username   = "azureuser"
    public_key = tls_private_key.ssh.public_key_openssh
  }

  network_interface_ids = [azurerm_network_interface.az_vm.id]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  tags = local.common_tags
}

# --- Auto-shutdown for zone VM (cost control) ---
resource "azurerm_dev_test_global_vm_shutdown_schedule" "az_vm" {
  virtual_machine_id = azurerm_linux_virtual_machine.az_vm.id
  location           = azurerm_resource_group.hadr.location
  enabled            = true

  daily_recurrence_time = var.auto_shutdown_time
  timezone              = "UTC"

  notification_settings {
    enabled = false
  }

  tags = local.common_tags
}

# =============================================================================
# PUBLIC LOAD BALANCER
# =============================================================================
# EXAM TOPIC: Standard vs Basic Load Balancer
#
# Standard LB (used here):
#   - Required for Availability Zones
#   - Zone-redundant frontend by default
#   - Supports HA Ports (all protocols/ports)
#   - Backend pool by NIC or IP
#   - Secure by default (NSG required to allow traffic)
#   - Supports cross-region load balancing
#   - SLA: 99.99%
#
# Basic LB (legacy, avoid):
#   - No zone support
#   - Open by default (no NSG needed, but less secure)
#   - Backend pool by NIC only
#   - No SLA guarantee
#   - Microsoft recommends Standard for all new deployments
#   - Basic LB retiring September 2025
#
# Architecture:
#   Internet → Public IP → LB Frontend → LB Rule → Backend Pool → VMs
#   Health probes determine which backend VMs receive traffic.
# =============================================================================

resource "azurerm_public_ip" "lb" {
  name                = "${var.prefix}-pub-lb-pip-${local.suffix}"
  location            = azurerm_resource_group.hadr.location
  resource_group_name = azurerm_resource_group.hadr.name
  allocation_method   = "Static"
  sku                 = "Standard" # Required for Standard LB

  tags = local.common_tags
}

resource "azurerm_lb" "public" {
  name                = "${var.prefix}-pub-lb-${local.suffix}"
  location            = azurerm_resource_group.hadr.location
  resource_group_name = azurerm_resource_group.hadr.name
  sku                 = "Standard" # Zone-redundant by default

  frontend_ip_configuration {
    name                 = "PublicFrontEnd"
    public_ip_address_id = azurerm_public_ip.lb.id
  }

  tags = local.common_tags
}

resource "azurerm_lb_backend_address_pool" "public" {
  name            = "avset-backend-pool"
  loadbalancer_id = azurerm_lb.public.id
}

# Associate the avset VM NICs with the backend pool
resource "azurerm_network_interface_backend_address_pool_association" "avset_vm" {
  count                   = 2
  network_interface_id    = azurerm_network_interface.avset_vm[count.index].id
  ip_configuration_name   = "internal"
  backend_address_pool_id = azurerm_lb_backend_address_pool.public.id
}

resource "azurerm_lb_probe" "http" {
  name                = "http-health-probe"
  loadbalancer_id     = azurerm_lb.public.id
  protocol            = "Tcp"
  port                = 80
  interval_in_seconds = 5
  number_of_probes    = 2
}

resource "azurerm_lb_rule" "http" {
  name                           = "http-rule"
  loadbalancer_id                = azurerm_lb.public.id
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = "PublicFrontEnd"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.public.id]
  probe_id                       = azurerm_lb_probe.http.id
  idle_timeout_in_minutes        = 4
  tcp_reset_enabled              = true
}

# =============================================================================
# INTERNAL LOAD BALANCER
# =============================================================================
# Demonstrates the internal (private) LB pattern for multi-tier applications:
#   Internet → Public LB → Web Tier → Internal LB → App/Business Tier → DB
#
# The internal LB gets a private IP from the compute subnet. Only resources
# within the VNet (or peered VNets) can reach it.
#
# EXAM TIP: Internal LBs are the correct answer when the question mentions:
#   - "private traffic only"
#   - "between tiers"
#   - "no public exposure"
#   - "backend services"
# =============================================================================

resource "azurerm_lb" "internal" {
  name                = "${var.prefix}-int-lb-${local.suffix}"
  location            = azurerm_resource_group.hadr.location
  resource_group_name = azurerm_resource_group.hadr.name
  sku                 = "Standard"

  frontend_ip_configuration {
    name                          = "InternalFrontEnd"
    subnet_id                     = var.compute_subnet_id
    private_ip_address_allocation = "Dynamic"
  }

  tags = local.common_tags
}

resource "azurerm_lb_backend_address_pool" "internal" {
  name            = "internal-backend-pool"
  loadbalancer_id = azurerm_lb.internal.id
}

# =============================================================================
# RECOVERY SERVICES VAULT & BACKUP
# =============================================================================
# EXAM TOPIC: Azure Backup Architecture
#
# Recovery Services Vault:
#   - Central management point for backup and site recovery
#   - Stores backup data (recovery points)
#   - Storage redundancy options: LRS, ZRS, GRS (exam default: GRS)
#   - GRS replicates data to paired region (300+ miles away)
#   - Soft delete: retains deleted backup data for 14 days (protection against
#     ransomware/accidental deletion)
#
# Azure Backup supports:
#   - Azure VMs (full VM snapshots)
#   - SQL Server in Azure VMs
#   - Azure Files
#   - SAP HANA in Azure VMs
#   - Azure Blobs
#   - Azure Disks
#   - Azure Database for PostgreSQL
#
# Backup vs Site Recovery:
#   ┌──────────────────┬──────────────┬───────────────────┐
#   │                  │ Azure Backup │ Azure Site Recovery│
#   ├──────────────────┼──────────────┼───────────────────┤
#   │ Purpose          │ Data protect │ DR / Failover      │
#   │ RPO              │ ~24h (daily) │ Seconds-minutes    │
#   │ RTO              │ Hours        │ Minutes             │
#   │ Scope            │ Data restore │ Full VM replication │
#   │ Cross-region     │ GRS storage  │ Continuous repl.    │
#   │ Exam keyword     │ "backup"     │ "disaster recovery" │
#   └──────────────────┴──────────────┴───────────────────┘
# =============================================================================

resource "azurerm_recovery_services_vault" "main" {
  name                = "${var.prefix}-rsv-${local.suffix}"
  location            = azurerm_resource_group.hadr.location
  resource_group_name = azurerm_resource_group.hadr.name
  sku                 = "Standard"
  storage_mode_type   = "GeoRedundant" # Exam default; replicates to paired region
  # soft_delete is enabled by default (Azure secure-by-default policy).
  # Cannot be disabled — protects against accidental/malicious deletion.

  tags = local.common_tags
}

# --- Backup Policy: Daily backup with 7-day retention (lab cost savings) ---
# Production would typically use 30-day daily + weekly/monthly/yearly retention.
resource "azurerm_backup_policy_vm" "daily" {
  name                = "${var.prefix}-daily-backup-${local.suffix}"
  resource_group_name = azurerm_resource_group.hadr.name
  recovery_vault_name = azurerm_recovery_services_vault.main.name

  timezone = "UTC"

  backup {
    frequency = "Daily"
    time      = "02:00" # Run backups at 2 AM UTC (off-peak)
  }

  retention_daily {
    count = 7 # Keep 7 daily recovery points (lab cost savings)
  }
}

# --- Register Availability Set VMs for Backup ---
# Demonstrates Azure Backup for IaaS VMs. Each VM gets its own protection
# container in the vault. Recovery points are crash-consistent by default;
# install the VM agent for application-consistent snapshots.
resource "azurerm_backup_protected_vm" "avset_vm" {
  count               = 2
  resource_group_name = azurerm_resource_group.hadr.name
  recovery_vault_name = azurerm_recovery_services_vault.main.name
  source_vm_id        = azurerm_linux_virtual_machine.avset_vm[count.index].id
  backup_policy_id    = azurerm_backup_policy_vm.daily.id
}

# =============================================================================
# TRAFFIC MANAGER
# =============================================================================
# EXAM TOPIC: Global Load Balancing with Traffic Manager
#
# Traffic Manager is a DNS-based traffic distributor. It does NOT proxy
# traffic — it returns the best endpoint IP via DNS resolution.
#
# Routing Methods (exam favorites):
#   - Priority:    Active/passive failover
#   - Weighted:    Distribute by percentage (canary deployments)
#   - Performance: Route to closest endpoint by latency
#   - Geographic:  Route by user's geographic location (compliance)
#   - MultiValue:  Return multiple healthy endpoints (client chooses)
#   - Subnet:      Map client IP ranges to specific endpoints
#
# Traffic Manager vs Front Door vs Application Gateway:
#   Q: "Global HTTP load balancing with WAF?"  → Front Door
#   Q: "Global DNS-based routing, any protocol?"  → Traffic Manager
#   Q: "Regional HTTP load balancing with WAF?"  → Application Gateway
#   Q: "Regional TCP/UDP load balancing?"  → Azure Load Balancer
#
# Traffic Manager works with ANY internet-facing endpoint:
#   - Azure endpoints (public IPs, App Services, Cloud Services)
#   - External endpoints (on-premises, other clouds)
#   - Nested profiles (combine routing methods)
# =============================================================================

resource "azurerm_traffic_manager_profile" "main" {
  name                   = "${var.prefix}-tm-${local.suffix}"
  resource_group_name    = azurerm_resource_group.hadr.name
  traffic_routing_method = "Performance"

  dns_config {
    relative_name = "${var.prefix}-tm-${local.suffix}"
    ttl           = 60
  }

  monitor_config {
    protocol                     = "HTTP"
    port                         = 80
    path                         = "/"
    interval_in_seconds          = 30
    timeout_in_seconds           = 10
    tolerated_number_of_failures = 3
  }

  tags = local.common_tags
}

# --- Traffic Manager endpoint pointing to Public LB ---
resource "azurerm_traffic_manager_azure_endpoint" "lb" {
  name               = "public-lb-endpoint"
  profile_id         = azurerm_traffic_manager_profile.main.id
  target_resource_id = azurerm_public_ip.lb.id
  weight             = 100
}
