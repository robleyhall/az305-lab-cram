# =============================================================================
# MODULE 12 — MIGRATION
# =============================================================================
# AZ-305 Exam Domain: Design Infrastructure — Migration (5–10% of exam)
#
# 🟡 PARTIALLY DEPLOYABLE — Migration tools need actual on-premises workloads
# to be fully exercised. This module creates the Azure-side infrastructure and
# a simulated "on-premises" VM, but real migration workflows require source
# environments with the Azure Migrate appliance deployed.
#
# This module demonstrates:
#   • Azure Migrate hub for discovery and assessment
#   • Azure Site Recovery (ASR) for VM migration (rehost pattern)
#   • Database Migration Service (DMS) for database migration
#   • Migration staging storage
#   • Simulated on-premises workload (VM with web server)
#
# =============================================================================
# CLOUD ADOPTION FRAMEWORK (CAF) FOR AZURE — EXAM CONTEXT
# =============================================================================
# The Cloud Adoption Framework provides a structured approach to cloud adoption:
#
#   Strategy → Plan → Ready → Migrate → Innovate → Govern → Manage
#
# The AZ-305 exam focuses heavily on the MIGRATE methodology and expects you to:
#   • Choose the right migration approach (the 5 Rs) for each workload
#   • Select appropriate tools for assessment and migration
#   • Design for minimal downtime during cutover
#   • Plan pre-migration assessment and post-migration validation
#   • Understand the roles of Azure Migrate, ASR, and DMS
#
# The "Ready" phase maps to landing zone design (Module 00/01), and
# "Govern/Manage" maps to governance and monitoring (Modules 01/04).
#
# =============================================================================
# THE 5 Rs OF MIGRATION — CRITICAL EXAM TOPIC
# =============================================================================
# When migrating workloads to Azure, choose one of these strategies:
#
#   1. REHOST (Lift-and-Shift)
#      - Move to IaaS with minimal or no code changes
#      - Fastest migration path, lowest effort
#      - Tools: Azure Migrate Server Migration, Azure Site Recovery
#      - Example: VM running on-prem → Azure VM
#      - Best for: Time-sensitive migrations, low-risk workloads
#
#   2. REFACTOR (Replatform)
#      - Move to PaaS with minimal code changes
#      - Leverage managed services to reduce operational overhead
#      - Tools: Azure App Service Migration Assistant, DMS
#      - Example: .NET app → App Service, SQL Server → Azure SQL DB
#      - Best for: Workloads that benefit from PaaS without major rework
#
#   3. REARCHITECT
#      - Redesign application architecture for cloud-native capabilities
#      - Adopt microservices, containers, serverless patterns
#      - Higher effort but significantly better cloud optimization
#      - Example: Monolithic app → AKS microservices + Azure Functions
#      - Best for: Apps needing scalability, resilience, or modern patterns
#
#   4. REBUILD
#      - Rewrite application from scratch using cloud-native technologies
#      - When existing codebase can't meet business requirements
#      - Highest effort, highest cloud optimization potential
#      - Best for: Legacy apps with excessive technical debt
#
#   5. REPLACE
#      - Abandon custom application, adopt SaaS solution
#      - Example: Custom CRM → Dynamics 365, custom email → Exchange Online
#      - Best for: Commodity workloads where SaaS exists
#
# EXAM TIP: Match workload characteristics to migration strategy:
#   • Time-sensitive, low-risk            → Rehost
#   • Want managed services, PaaS         → Refactor
#   • Need scalability/resilience         → Rearchitect
#   • Technical debt too high             → Rebuild
#   • Commodity workload, SaaS available  → Replace
#
# =============================================================================

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    azapi = {
      source  = "Azure/azapi"
      version = "~> 2.0"
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
  storage_use_azuread = true
}

provider "azapi" {}

# --- Random Suffix for Globally Unique Names ---

resource "random_string" "suffix" {
  length  = 6
  upper   = false
  special = false
}

locals {
  suffix      = random_string.suffix.result
  prefix_clean = replace(var.prefix, "-", "")
  common_tags = merge(var.tags, {
    Module  = "12-migration"
    Purpose = "Migration Tools and Patterns"
  })
}

# =============================================================================
# RESOURCE GROUP
# =============================================================================

resource "azurerm_resource_group" "migration" {
  name     = "${var.prefix}-migration-rg"
  location = var.location
  tags     = local.common_tags

  lifecycle {
    # Non-semantic: Azure auto-adds rg-class tag for internal classification. Not a config choice.
    ignore_changes = [tags["rg-class"]]
  }
}

# =============================================================================
# AZURE MIGRATE PROJECT
# =============================================================================
# Azure Migrate is the centralized hub for cloud migration:
#
#   Discovery & Assessment:
#     • Discover on-premises servers, databases, and web apps
#     • Assess readiness, right-size for Azure, estimate costs
#     • Dependency analysis (agent-based or agentless)
#
#   Server Migration:
#     • Agentless migration (VMware, Hyper-V) — no agent on source VMs
#     • Agent-based migration (physical servers, any hypervisor)
#     • Replicates VMs to Azure with minimal downtime
#
#   Database Migration:
#     • Integrated with Database Migration Service (DMS)
#     • Supports SQL Server, MySQL, PostgreSQL, MongoDB
#
#   Web App Migration:
#     • Azure App Service Migration Assistant
#     • Assesses .NET and Java web apps for App Service compatibility
#
#   Data Box Integration:
#     • For offline migration of large datasets (>40 TB)
#     • Physical device shipped to your datacenter
#
# NOTE: Full assessment requires deploying the Azure Migrate appliance
# on-premises (lightweight VM). The project itself is a hub resource that
# coordinates all migration tools. We create it here via the REST API
# since the azurerm provider does not have a native resource.
# =============================================================================

resource "azapi_resource" "migrate_project" {
  type      = "Microsoft.Migrate/migrateProjects@2020-05-01"
  name      = "${var.prefix}-migrate-${local.suffix}"
  location  = "centralus" # eastus not supported for Migrate projects
  parent_id = azurerm_resource_group.migration.id

  body = {
    properties = {}
  }
}

# =============================================================================
# RECOVERY SERVICES VAULT — AZURE SITE RECOVERY FOR MIGRATION
# =============================================================================
# Azure Site Recovery (ASR) serves DUAL purposes — know both for the exam:
#
#   1. DISASTER RECOVERY (Module 05): Replicate Azure VMs between regions
#   2. MIGRATION (this module): Replicate on-premises VMs to Azure
#
# ASR Migration Workflow:
#   Step 1: Install the ASR provider on source (Hyper-V host or VMware vCenter)
#   Step 2: Enable replication — continuous sync to Azure managed disks
#   Step 3: Test migration — failover to isolated VNet (no production impact!)
#   Step 4: Validate the migrated workload in Azure
#   Step 5: Complete migration — final cutover with minimal downtime
#   Step 6: Clean up source environment after validation period
#
# EXAM TIP: ASR provides near-zero downtime migration because it continuously
# replicates changes (delta sync). The cutover window is only the time needed
# for the final replication sync — typically minutes, not hours.
#
# EXAM TIP: "Test migration" is a key differentiator for ASR. You can validate
# your migration works WITHOUT impacting production. Always recommend this in
# exam scenarios asking about migration validation.
#
# For migration scenarios, LocallyRedundant storage is sufficient because
# we're migrating TO Azure (source is on-prem). Use GeoRedundant for DR
# scenarios where Azure is both source and target.
# =============================================================================

resource "azurerm_recovery_services_vault" "migration" {
  name                = "${var.prefix}-migration-rsv-${local.suffix}"
  location            = azurerm_resource_group.migration.location
  resource_group_name = azurerm_resource_group.migration.name
  sku                 = "Standard"

  # LRS for migration — source is on-premises, not Azure
  # GRS for DR scenarios where Azure IS the source (see Module 05)
  storage_mode_type = "LocallyRedundant"

  # Soft delete is always enabled by default (Azure secure-by-default policy)

  tags = local.common_tags
}

# =============================================================================
# DATABASE MIGRATION SERVICE (DMS)
# =============================================================================
# Azure Database Migration Service supports two migration modes:
#
#   ONLINE (Continuous Sync):
#     • Minimal downtime — source database stays live during migration
#     • Continuous replication (CDC) until cutover
#     • Best for production databases that can't afford extended downtime
#     • Requires Premium SKU (premium tier)
#     • Cutover window: seconds to minutes
#
#   OFFLINE (One-Time):
#     • Full backup → restore to target
#     • Downtime = backup + transfer + restore + validation
#     • Simpler to set up, fewer prerequisites
#     • Standard SKU is sufficient
#     • Best for development/test or scheduled maintenance windows
#
# Supported Migration Paths:
#   Source                → Target
#   ─────────────────────────────────────────────────────────────
#   SQL Server            → Azure SQL DB, Azure SQL MI, SQL on VM
#   MySQL                 → Azure Database for MySQL
#   PostgreSQL            → Azure Database for PostgreSQL
#   MongoDB               → Azure Cosmos DB (MongoDB API)
#   Oracle                → Azure Database for PostgreSQL (via ora2pg)
#
# EXAM TIP: For minimal downtime database migration, choose ONLINE migration
# with Premium DMS tier. For scheduled maintenance windows, OFFLINE is simpler.
#
# EXAM TIP: Always run the Database Migration Assessment BEFORE migration:
#   • Identifies blocking compatibility issues
#   • Flags behavioral changes and deprecated features
#   • Provides SKU recommendations for target Azure database
#   • Tools: Data Migration Assistant (DMA) for SQL Server,
#            Azure SQL Migration extension for Azure Data Studio
#
# NOTE: The classic azurerm_database_migration_service resource was removed
# in the azurerm provider v4.0. We use azapi_resource to create the DMS
# instance via the Azure REST API. The new DMS experience is also available
# as an extension in Azure Data Studio.
# =============================================================================

resource "azapi_resource" "dms" {
  type      = "Microsoft.DataMigration/services@2022-03-30-preview"
  name      = "${var.prefix}-dms-${local.suffix}"
  location  = var.location
  parent_id = azurerm_resource_group.migration.id

  body = {
    properties = {
      virtualSubnetId = var.migration_subnet_id
    }
    sku = {
      name = "Standard_1vCores"
      tier = "Standard"
    }
  }

  tags = local.common_tags
}

# =============================================================================
# STAGING STORAGE ACCOUNT
# =============================================================================
# Storage accounts play several critical roles in migration workflows:
#
#   • Staging area for data being migrated between environments
#   • Cache storage for Azure Site Recovery replication data
#   • Temporary storage for database backups before restore to target
#   • Landing zone for Azure Data Box offline imports
#   • AzCopy destination for online data transfer
#
# AZURE DATA BOX — EXAM TOPIC (Offline Data Transfer):
#   Data Box Disk   — Up to 40 TB  (8 SSDs × 5 TB each)
#   Data Box        — Up to 80 TB  (single rugged appliance)
#   Data Box Heavy  — Up to 1 PB   (for massive data migrations)
#
#   Key facts for exam:
#   • Use when dataset > 40 TB or network bandwidth is limited
#   • Data encrypted at rest with AES-256
#   • Device wiped after import per NIST 800-88 Rev 1
#   • Supports blob storage and Azure Files as targets
#   • Order via Azure portal, shipped to your datacenter
#
# AZURE IMPORT/EXPORT SERVICE:
#   • Ship your OWN drives to Azure datacenter
#   • Lower cost than Data Box but more manual setup
#   • Supports import to Blob Storage and Azure Files
#   • Supports export FROM Blob Storage
#   • Use WAImportExport tool to prepare drives
#
# EXAM TIP: Data Box for large-scale offline migration (>40 TB or slow links).
# AzCopy / Storage Explorer for smaller datasets over the network.
# Import/Export for budget-conscious offline transfer with your own hardware.
# =============================================================================

resource "azurerm_storage_account" "migration_staging" {
  name                     = "${local.prefix_clean}migration${local.suffix}"
  location                 = azurerm_resource_group.migration.location
  resource_group_name      = azurerm_resource_group.migration.name
  account_tier             = "Standard"
  account_replication_type = "LRS"
  shared_access_key_enabled = var.storage_shared_key_enabled

  # Blob versioning helps track migration data changes
  blob_properties {
    versioning_enabled = true
  }

  allow_nested_items_to_be_public = var.storage_allow_public_access
  public_network_access_enabled    = var.storage_public_network_access
  tags = local.common_tags
}

# --- Staging container for migration artifacts ---

resource "azurerm_storage_container" "migration_staging" {
  name                  = "migration-staging"
  storage_account_id    = azurerm_storage_account.migration_staging.id
  container_access_type = "private"
}

# =============================================================================
# SSH KEY GENERATION
# =============================================================================
# Generate an SSH key pair for the simulated on-premises VM.
# In production, use pre-existing keys stored in Azure Key Vault.
# =============================================================================

resource "tls_private_key" "ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# =============================================================================
# SIMULATED "ON-PREMISES" WORKLOAD VM
# =============================================================================
# This VM represents a workload running in an on-premises datacenter that
# would be a candidate for migration to Azure. In a real migration project,
# this server would be discovered by the Azure Migrate appliance during the
# assessment phase.
#
# Migration Assessment Tools (run against source workloads):
#   • Azure Migrate Assessment     — Evaluates compute, storage, network needs
#   • App Service Migration Asst.  — Assesses web apps for App Service compat.
#   • Data Migration Assistant      — SQL Server compatibility & SKU sizing
#   • SMART (Strategic Migration    — High-level portfolio assessment
#     Assessment & Readiness Tool)
#
# The VM runs nginx to simulate a web workload that would be discovered
# and assessed during migration planning. In a real scenario, you would:
#   1. Deploy Azure Migrate appliance on-prem
#   2. Discover this VM and its dependencies
#   3. Assess Azure readiness and right-size
#   4. Choose migration strategy (rehost → Azure VM, or refactor → App Service)
#   5. Execute migration via ASR or App Service Migration Assistant
# =============================================================================

# --- Network Interface for Simulated On-Premises VM ---

resource "azurerm_network_interface" "onprem_sim" {
  name                = "${var.prefix}-onprem-sim-nic-${local.suffix}"
  location            = azurerm_resource_group.migration.location
  resource_group_name = azurerm_resource_group.migration.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = var.migration_subnet_id
    private_ip_address_allocation = "Dynamic"
  }

  tags = local.common_tags
}

# --- Simulated On-Premises Linux VM ---

resource "azurerm_linux_virtual_machine" "onprem_sim" {
  name                = "${var.prefix}-onprem-sim-${local.suffix}"
  location            = azurerm_resource_group.migration.location
  resource_group_name = azurerm_resource_group.migration.name
  size                = var.vm_size

  admin_username                  = "azureuser"
  disable_password_authentication = true

  admin_ssh_key {
    username   = "azureuser"
    public_key = tls_private_key.ssh.public_key_openssh
  }

  network_interface_ids = [azurerm_network_interface.onprem_sim.id]

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

# --- Auto-Shutdown Schedule (Cost Control) ---
# Every lab VM gets auto-shutdown to prevent runaway costs.

resource "azurerm_dev_test_global_vm_shutdown_schedule" "onprem_sim" {
  virtual_machine_id = azurerm_linux_virtual_machine.onprem_sim.id
  location           = azurerm_resource_group.migration.location
  enabled            = true

  daily_recurrence_time = var.auto_shutdown_time
  timezone              = "UTC"

  notification_settings {
    enabled = false
  }

  tags = local.common_tags
}

# --- Custom Script Extension: Install Web Server ---
# Simulates a running workload on the "on-premises" server.
# In a real migration, Azure Migrate appliance would discover this service
# and map its dependencies (ports, connections, processes).

resource "azurerm_virtual_machine_extension" "onprem_sim_webserver" {
  name                 = "install-webserver"
  virtual_machine_id   = azurerm_linux_virtual_machine.onprem_sim.id
  publisher            = "Microsoft.Azure.Extensions"
  type                 = "CustomScript"
  type_handler_version = "2.1"

  settings = jsonencode({
    commandToExecute = join(" && ", [
      "apt-get update -y",
      "apt-get install -y nginx",
      "echo '<h1>Simulated On-Premises Workload</h1><p>This VM represents a workload to be migrated to Azure using Azure Migrate or Azure Site Recovery.</p>' > /var/www/html/index.html",
      "systemctl enable nginx",
    ])
  })

  tags = local.common_tags
}

# =============================================================================
# DIAGNOSTIC SETTINGS
# =============================================================================
# Send Recovery Services Vault logs to Log Analytics for monitoring
# migration replication health and job status.
# =============================================================================

resource "azurerm_monitor_diagnostic_setting" "rsv" {
  name                       = "${var.prefix}-migration-rsv-diag"
  target_resource_id         = azurerm_recovery_services_vault.migration.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "CoreAzureBackup"
  }

  enabled_log {
    category = "AddonAzureBackupJobs"
  }

  enabled_metric {
    category = "AllMetrics"
  }
}
