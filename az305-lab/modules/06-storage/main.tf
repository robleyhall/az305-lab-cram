# =============================================================================
# AZ-305 Lab — Module 06: Storage Solutions
# =============================================================================
# Demonstrates Azure Storage design patterns for the AZ-305 exam.
#
# AZ-305 Exam Relevance (20-25% — "Design Data Storage Solutions"):
#   - Storage account types: GPv2, BlobStorage, BlockBlobStorage, FileStorage
#   - Replication options: LRS, ZRS, GRS, RA-GRS, GZRS, RA-GZRS
#   - Access tiers: Hot, Cool, Cold, Archive — lifecycle management
#   - Blob types: Block, Append, Page
#   - Managed disks: Standard HDD, Standard SSD, Premium SSD, Ultra Disk
#   - Azure Files for SMB/NFS scenarios
#   - Data Lake Storage Gen2 (hierarchical namespace)
#   - Storage security: firewalls, private endpoints, SAS, encryption
#   - Immutable storage and legal hold
#
# Cost: ~$1.50/day (multiple storage accounts + managed disks + private endpoint)
# =============================================================================

# =============================================================================
# AZ-305 EXAM TOPIC: Storage Account Types
# ---------------------------------------------------------------------------
# GPv2 (General Purpose v2) — DEFAULT choice for most scenarios.
#   Supports Blob, File, Queue, Table. All access tiers. All replication.
#
# BlobStorage — Legacy, superseded by GPv2. Avoid in new designs.
#
# BlockBlobStorage — Premium performance for block/append blobs ONLY.
#   Use for: IoT telemetry, high-throughput analytics, low-latency workloads.
#   Only supports LRS and ZRS (no geo-replication).
#
# FileStorage — Premium performance for Azure Files ONLY.
#   Use for: Enterprise file shares needing sub-millisecond latency.
#   Only supports LRS and ZRS.
#
# Exam Tip: "Which storage account kind supports all services and tiers?"
#   Answer: StorageV2 (GPv2)
# =============================================================================

# =============================================================================
# AZ-305 EXAM TOPIC: Replication Options (CRITICAL — expect 2-3 questions)
# ---------------------------------------------------------------------------
# LRS  — 3 copies in a SINGLE datacenter (cheapest, least durable)
#         Protects against: drive/rack failure
#         Does NOT protect against: datacenter or region outage
#         Durability: 11 nines (99.999999999%)
#
# ZRS  — 3 copies across AVAILABILITY ZONES in one region
#         Protects against: single-zone failure
#         Does NOT protect against: regional disaster
#         Durability: 12 nines
#
# GRS  — 6 copies total: 3 LRS in primary + 3 LRS in paired region
#         Secondary is NOT readable until failover
#         Durability: 16 nines
#
# RA-GRS — GRS + READ ACCESS to secondary region (without failover)
#         Use when: you need read availability during primary outage
#         Secondary endpoint: {account}-secondary.blob.core.windows.net
#
# GZRS — 3 copies across zones in primary (ZRS) + 3 LRS in paired region
#         Best durability + availability combination
#
# RA-GZRS — GZRS + read access to secondary
#         Maximum resilience option
#
# Exam Pattern: "Which replication supports readable secondary without
# failover?" → RA-GRS or RA-GZRS
# "Which provides zone + geo redundancy?" → GZRS / RA-GZRS
# ---------------------------------------------------------------------------
#
# Premium accounts (BlockBlobStorage, FileStorage) support ONLY LRS and ZRS.
# =============================================================================

# =============================================================================
# AZ-305 EXAM TOPIC: Access Tiers (Hot / Cool / Cold / Archive)
# ---------------------------------------------------------------------------
# Hot     — Frequent access. Highest storage cost, lowest access cost.
#           Default tier for new storage accounts.
#
# Cool    — Infrequent access (≥30 days). Lower storage, higher access cost.
#           30-day early deletion penalty.
#
# Cold    — Rarely accessed (≥90 days). Even lower storage cost.
#           90-day early deletion penalty.
#
# Archive — Offline storage. Lowest storage cost, highest access cost.
#           180-day early deletion penalty.
#           Data is OFFLINE — must rehydrate before reading (hours).
#           Rehydrate priority: Standard (up to 15 hours) or High (< 1 hour).
#
# Lifecycle management automates tier transitions: Hot → Cool → Archive → Delete
# Set policies based on last modified date or last accessed date.
#
# Exam Pattern: "Minimize cost for data accessed once per quarter"
#   → Cool tier with lifecycle policy to Archive after 90 days
# =============================================================================

# =============================================================================
# AZ-305 EXAM TOPIC: Blob Types
# ---------------------------------------------------------------------------
# Block Blob  — Default. Optimized for upload (text, binary). Up to 190.7 TiB.
#               Best for: documents, images, video, backups.
#
# Append Blob — Optimized for append operations. Cannot modify existing blocks.
#               Best for: logging, audit trails, streaming data.
#
# Page Blob   — Optimized for random read/write. Fixed 512-byte pages.
#               Best for: VM disks (VHDs), databases needing random I/O.
#               Note: Managed disks now abstract page blobs.
# =============================================================================

# =============================================================================
# AZ-305 EXAM TOPIC: Azure Files vs Blob Storage
# ---------------------------------------------------------------------------
# Azure Files:
#   - SMB (445) and NFS (2049) protocol support
#   - Mount as network drive on Windows/Linux/macOS
#   - Use for: lift-and-shift file shares, shared app config, dev tools
#   - Azure File Sync: sync on-prem file servers with Azure Files
#   - Supports AD DS / Azure AD DS authentication
#
# Blob Storage:
#   - REST API access (HTTP/HTTPS)
#   - Use for: unstructured data, media, backups, data lake
#   - CDN integration for static content
#   - Immutable storage (WORM) support
#   - Lifecycle management / tiering
#
# Exam Pattern: "Application needs shared file access via SMB"
#   → Azure Files
# "Application stores unstructured data accessed via REST"
#   → Blob Storage
# =============================================================================

# =============================================================================
# AZ-305 EXAM TOPIC: Managed Disk Types
# ---------------------------------------------------------------------------
# Standard HDD (Standard_LRS) — Lowest cost. Dev/test, backups.
#   Max IOPS: 500, Max throughput: 60 MB/s
#
# Standard SSD (StandardSSD_LRS) — Better consistency than HDD.
#   Max IOPS: 6,000, Max throughput: 750 MB/s
#   Good for: web servers, lightly used enterprise apps
#
# Premium SSD (Premium_LRS) — Production workloads.
#   Max IOPS: 20,000, Max throughput: 900 MB/s
#   REQUIRED for single-instance VM SLA (99.9%)
#
# Premium SSD v2 — Granular IOPS/throughput provisioning.
#   Best for: workloads needing sub-millisecond latency
#
# Ultra Disk (UltraSSD_LRS) — Highest performance.
#   Max IOPS: 160,000, Max throughput: 4,000 MB/s
#   Use for: SAP HANA, SQL Server, transaction-heavy workloads
#   Constraints: limited region/zone support, must be attached to VM
#
# Exam Pattern: "Single VM with 99.9% SLA" → requires Premium SSD or Ultra
# =============================================================================

# =============================================================================
# AZ-305 EXAM TOPIC: Storage Security
# ---------------------------------------------------------------------------
# Shared Access Signatures (SAS):
#   - Account SAS: access to multiple services (blob, file, queue, table)
#   - Service SAS: access to single service
#   - User Delegation SAS: signed with Azure AD credentials (MOST SECURE)
#   - Stored Access Policy: reusable; can revoke without regenerating keys
#
# Encryption at Rest:
#   - Microsoft-managed keys (MMK): default, no config needed
#   - Customer-managed keys (CMK): stored in Key Vault, you control rotation
#   - Customer-provided keys: supplied per-request (rare)
#   - Infrastructure encryption: double encryption (MMK + CMK layers)
#
# Network Security:
#   - Storage firewall: allow specific IPs / VNets
#   - Service Endpoints: routes traffic via Azure backbone, public IP remains
#   - Private Endpoints: private IP in your VNet, FQDN resolves privately
#
# Exam Pattern: "Most secure way to grant temporary access?"
#   → User Delegation SAS with short expiry
# "How to prevent data exfiltration to internet?"
#   → Private Endpoint + deny public access
# =============================================================================

# =============================================================================
# AZ-305 EXAM TOPIC: Private Endpoint vs Service Endpoint
# ---------------------------------------------------------------------------
# Service Endpoint (legacy, simpler):
#   - Routes traffic through Azure backbone from specific subnets
#   - Storage account STILL HAS a public IP
#   - Configured at subnet level (Microsoft.Storage service endpoint)
#   - No DNS changes required
#   - No additional cost
#
# Private Endpoint (modern, preferred for AZ-305):
#   - Creates a private NIC in YOUR subnet with a private IP
#   - Storage FQDN resolves to private IP (via Private DNS Zone)
#   - No public IP exposure possible (if public access disabled)
#   - Works across VNet peering and VPN/ExpressRoute
#   - Small hourly cost (~$0.01/hr)
#
# Exam Preference: Private Endpoint is almost always the correct answer
# for "most secure" networking questions.
# =============================================================================

# =============================================================================
# AZ-305 EXAM TOPIC: Immutable Storage & Legal Hold (Concept Only)
# ---------------------------------------------------------------------------
# Immutable Blob Storage (WORM — Write Once, Read Many):
#   - Time-based retention: locked for N days, cannot delete/modify
#   - Legal hold: indefinite lock until explicitly removed
#   - Supports SEC 17a-4(f), CFTC, FINRA compliance
#   - Once locked, cannot be shortened (can be extended)
#
# Use cases: financial records, medical records, audit logs
# Not deployed here — production-only feature with irreversible locks.
# =============================================================================

# =============================================================================
# AZ-305 EXAM TOPIC: Data Lake Storage Gen2
# ---------------------------------------------------------------------------
# ADLS Gen2 = Azure Storage Account + Hierarchical Namespace (HNS)
#   - HNS enables TRUE directory operations (rename dir = atomic, O(1))
#   - Without HNS, "directories" are just blob name prefixes (rename = copy all)
#   - Supports POSIX-like ACLs (user, group, other permissions)
#   - Compatible with Hadoop, Spark, Databricks, Synapse Analytics
#   - Uses ABFS driver (abfs://) instead of WASB
#
# Key differentiator on exam: "hierarchical namespace = true" → ADLS Gen2
# Without HNS → standard Blob Storage with virtual directories
#
# Cost: Same pricing as standard blob storage (no premium for HNS)
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
    http = {
      source  = "hashicorp/http"
      version = "~> 3.4"
    }
  }
}

provider "azurerm" {
  features {}
  storage_use_azuread = true
}

# --- Data Sources ---

data "azurerm_client_config" "current" {}

data "azurerm_resource_group" "foundation" {
  name = var.foundation_resource_group_name
}

# Retrieve deployer's public IP for storage firewall rules
data "http" "my_ip" {
  url = "https://api.ipify.org"
}

# --- Local Values ---

locals {
  common_tags = merge(var.tags, {
    Module  = "06-storage"
    Purpose = "Storage patterns — accounts, tiers, replication, security"
  })

  # Storage account names: max 24 chars, lowercase alphanumeric only (no hyphens)
  prefix_clean         = replace(var.prefix, "-", "")
  main_storage_name    = "${local.prefix_clean}storage${random_string.suffix.result}"
  premium_storage_name = "${local.prefix_clean}premblob${random_string.suffix.result}"
  datalake_name        = "${local.prefix_clean}datalake${random_string.suffix.result}"
}

# --- Random Suffix for Globally Unique Names ---

resource "random_string" "suffix" {
  length  = 6
  upper   = false
  special = false
}

# =============================================================================
# RESOURCE GROUP
# =============================================================================

resource "azurerm_resource_group" "storage" {
  name     = "${var.prefix}-storage-rg"
  location = var.location
  tags     = local.common_tags

  lifecycle {
    # Non-semantic: Azure auto-adds rg-class tag for internal classification. Not a config choice.
    ignore_changes = [tags["rg-class"]]
  }
}

# =============================================================================
# PRIMARY STORAGE ACCOUNT — General Purpose v2 (GPv2) with GRS
# =============================================================================
# This is the "default" storage account type for most AZ-305 scenarios.
# GPv2 supports all storage services (Blob, File, Queue, Table) and all
# access tiers (Hot, Cool, Cold, Archive).
#
# GRS replication demonstrates geo-redundancy: 3 copies in the primary region
# + 3 copies asynchronously replicated to the paired region (e.g., East US →
# West US). This is a CRITICAL exam topic — understand when to choose GRS
# vs RA-GRS vs GZRS.
# =============================================================================

resource "azurerm_storage_account" "main" {
  name                = local.main_storage_name
  resource_group_name = azurerm_resource_group.storage.name
  location            = azurerm_resource_group.storage.location

  account_tier             = "Standard"
  account_replication_type = "GRS"
  account_kind             = "StorageV2"
  access_tier              = "Hot"

  # Security hardening
  min_tls_version            = "TLS1_2"
  https_traffic_only_enabled = true
  shared_access_key_enabled  = false # Required for Terraform provider data plane operations
  is_hns_enabled             = false # Standard blob — NOT Data Lake

  # Blob data protection
  blob_properties {
    versioning_enabled = true

    delete_retention_policy {
      days = 7
    }

    container_delete_retention_policy {
      days = 7
    }
  }

  # Network rules: default deny, allow from storage subnet + deployer IP
  network_rules {
    default_action             = "Deny"
    virtual_network_subnet_ids = [var.storage_subnet_id]
    ip_rules                   = [chomp(data.http.my_ip.response_body)]
    bypass                     = ["AzureServices"]
  }

  allow_nested_items_to_be_public = false
  public_network_access_enabled    = false # Policy-enforced steady state
  tags = local.common_tags
}

# --- Diagnostic Settings for Primary Storage Account ---
# Routes storage metrics to the centralized Log Analytics workspace from Module 00.

resource "azurerm_monitor_diagnostic_setting" "storage_account" {
  name                       = "${var.prefix}-storage-diag"
  target_resource_id         = azurerm_storage_account.main.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_metric {
    category = "Transaction"
  }

  enabled_metric {
    category = "Capacity"
  }
}

# Blob-service-level diagnostics (read/write/delete logs)
resource "azurerm_monitor_diagnostic_setting" "blob_service" {
  name                       = "${var.prefix}-blob-diag"
  target_resource_id         = "${azurerm_storage_account.main.id}/blobServices/default"
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "StorageRead"
  }

  enabled_log {
    category = "StorageWrite"
  }

  enabled_log {
    category = "StorageDelete"
  }

  enabled_metric {
    category = "Transaction"
  }

  enabled_metric {
    category = "Capacity"
  }
}

# =============================================================================
# BLOB CONTAINERS
# =============================================================================
# Demonstrates container access levels:
#   - Private: No anonymous access (default, recommended)
#   - Blob: Anonymous read for blobs only (public URL per blob)
#   - Container: Anonymous read for container + blobs (list + read)
#
# AZ-305 best practice: ALWAYS use Private unless you have a specific
# public-access requirement (e.g., static website assets).
# =============================================================================

resource "azurerm_storage_container" "documents" {
  name                  = "documents"
  storage_account_id    = azurerm_storage_account.main.id
  container_access_type = "private"
}

resource "azurerm_storage_container" "public_assets" {
  name                  = "public-assets"
  storage_account_id    = azurerm_storage_account.main.id
  container_access_type = "private" # Public access blocked by subscription policy
}

# =============================================================================
# LIFECYCLE MANAGEMENT POLICY
# =============================================================================
# Automates tier transitions to optimize cost:
#   Hot → Cool (30 days) → Archive (90 days) → Delete (365 days)
#
# AZ-305 Exam Pattern: "How to minimize storage costs for data that is
# frequently accessed for the first month, then rarely accessed?"
#   → Lifecycle management with Cool after 30 days, Archive after 90 days.
#
# Rules can filter by:
#   - Blob prefix (e.g., "logs/")
#   - Blob index tags
#   - Blob type (blockBlob, appendBlob)
# =============================================================================

resource "azurerm_storage_management_policy" "lifecycle" {
  storage_account_id = azurerm_storage_account.main.id

  rule {
    name    = "tiered-lifecycle"
    enabled = true

    filters {
      blob_types   = ["blockBlob"]
      prefix_match = ["documents/"]
    }

    actions {
      base_blob {
        tier_to_cool_after_days_since_modification_greater_than    = 30
        tier_to_archive_after_days_since_modification_greater_than = 90
        delete_after_days_since_modification_greater_than          = 365
      }

      snapshot {
        delete_after_days_since_creation_greater_than = 90
      }

      version {
        delete_after_days_since_creation = 90
      }
    }
  }
}

# =============================================================================
# AZURE FILES SHARE
# =============================================================================
# Azure Files provides fully managed SMB/NFS file shares in the cloud.
#
# Tiers (Standard account):
#   - TransactionOptimized: default, balanced cost for mixed workloads
#   - Hot: optimized for file share workloads with frequent access
#   - Cool: cost-optimized for infrequently accessed data
#
# Premium tiers (FileStorage account type — not shown here):
#   - SSD-backed, provisioned IOPS, sub-millisecond latency
#   - Only supports LRS and ZRS
#
# Use cases:
#   - Lift-and-shift: replace on-prem file servers
#   - Shared application settings across multiple VMs
#   - Azure File Sync: hybrid scenario with on-prem caching
#   - Diagnostic logs and crash dumps
# =============================================================================

resource "azurerm_storage_share" "fileshare" {
  name               = "az305-lab-fileshare"
  storage_account_id = azurerm_storage_account.main.id
  quota              = 5 # GB
  access_tier        = "TransactionOptimized"
}

# =============================================================================
# PREMIUM BLOCK BLOB STORAGE ACCOUNT
# =============================================================================
# Premium tier uses SSD-backed storage for consistently low latency.
# BlockBlobStorage kind supports ONLY block blobs and append blobs.
#
# Key constraints:
#   - Only LRS and ZRS replication (no geo-redundancy)
#   - No access tier concept (no Hot/Cool/Archive)
#   - Higher cost per GB, lower cost per transaction
#
# Use cases:
#   - IoT / telemetry ingestion (high write throughput)
#   - Interactive workloads (maps, real-time analytics)
#   - AI/ML training data (low-latency reads)
# =============================================================================

resource "azurerm_storage_account" "premium_blob" {
  name                = local.premium_storage_name
  resource_group_name = azurerm_resource_group.storage.name
  location            = azurerm_resource_group.storage.location

  account_tier             = "Premium"
  account_kind             = "BlockBlobStorage"
  account_replication_type = "LRS"

  min_tls_version            = "TLS1_2"
  https_traffic_only_enabled = true
  shared_access_key_enabled  = false

  allow_nested_items_to_be_public = false
  public_network_access_enabled    = false # Policy-enforced steady state
  tags = local.common_tags
}

# =============================================================================
# DATA LAKE STORAGE GEN2 (ADLS Gen2)
# =============================================================================
# ADLS Gen2 = Storage account with is_hns_enabled = true
#
# THE key differentiator: hierarchical namespace enables true directory
# operations. Without HNS, directories are virtual (blob name prefixes).
#
# With HNS (ADLS Gen2):
#   - Rename directory = atomic O(1) metadata operation
#   - POSIX ACLs for fine-grained access control
#   - Compatible with Hadoop (ABFS driver), Spark, Databricks, Synapse
#
# Without HNS (standard Blob):
#   - Rename directory = copy every blob + delete originals (O(n))
#   - Only container-level access control
#
# Cost: Same per-GB pricing as standard blob. No premium for HNS.
#
# Exam Pattern: "Architect a big data analytics platform"
#   → ADLS Gen2 (HNS enabled) + Synapse Analytics / Databricks
# =============================================================================

resource "azurerm_storage_account" "datalake" {
  name                = local.datalake_name
  resource_group_name = azurerm_resource_group.storage.name
  location            = azurerm_resource_group.storage.location

  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"
  access_tier              = "Hot"
  is_hns_enabled           = true # ← THIS makes it ADLS Gen2

  min_tls_version            = "TLS1_2"
  https_traffic_only_enabled = true
  shared_access_key_enabled  = false

  allow_nested_items_to_be_public = false
  public_network_access_enabled    = false # Policy-enforced steady state
  tags = local.common_tags
}# =============================================================================
# MANAGED DISKS
# =============================================================================
# Azure Managed Disks abstract the underlying storage account for VM disks.
# You select a disk type (HDD/SSD/Ultra) and Azure handles replication,
# encryption, and placement.
#
# IMPORTANT for AZ-305:
#   - Single VM SLA (99.9%) requires ALL disks to be Premium SSD or Ultra
#   - Standard HDD/SSD → no single-instance SLA
#   - Availability Set SLA (99.95%) works with any disk type
#   - Availability Zone SLA (99.99%) works with any disk type
# =============================================================================

# --- Standard HDD Managed Disk ---
# Lowest cost option. Suitable for dev/test, backups, infrequently accessed data.

resource "azurerm_managed_disk" "standard" {
  name                = "${var.prefix}-disk-standard"
  resource_group_name = azurerm_resource_group.storage.name
  location            = azurerm_resource_group.storage.location

  storage_account_type = "Standard_LRS"
  create_option        = "Empty"
  disk_size_gb         = 32

  tags = local.common_tags
}

# --- Premium SSD Managed Disk (P4 — 32 GB) ---
# Production workloads. Required for single-instance VM SLA.
# P4 = 32 GB, 120 IOPS baseline, 25 MB/s throughput.

resource "azurerm_managed_disk" "premium" {
  name                = "${var.prefix}-disk-premium"
  resource_group_name = azurerm_resource_group.storage.name
  location            = azurerm_resource_group.storage.location

  storage_account_type = "Premium_LRS"
  create_option        = "Empty"
  disk_size_gb         = 32

  tags = local.common_tags
}

# --- Ultra Disk (NOT DEPLOYED — Cost Warning) ---
# =============================================================================
# Ultra Disks provide the highest performance tier:
#   - Up to 160,000 IOPS and 4,000 MB/s throughput
#   - Sub-millisecond latency
#   - Dynamically adjust IOPS/throughput without detaching
#
# Constraints:
#   - Must attach to a VM (cannot exist standalone in all regions)
#   - Limited region and VM-size support
#   - ONLY UltraSSD_LRS replication
#   - Cost: ~$4.38/month per provisioned disk + IOPS + throughput charges
#
# To deploy (if needed for testing):
#
# resource "azurerm_managed_disk" "ultra" {
#   name                = "${var.prefix}-disk-ultra"
#   resource_group_name = azurerm_resource_group.storage.name
#   location            = azurerm_resource_group.storage.location
#
#   storage_account_type = "UltraSSD_LRS"
#   create_option        = "Empty"
#   disk_size_gb         = 32
#   disk_iops_read_write = 500
#   disk_mbps_read_write = 8
#
#   tags = local.common_tags
# }
# =============================================================================

# =============================================================================
# PRIVATE ENDPOINT FOR BLOB STORAGE
# =============================================================================
# Private Endpoint creates a network interface in the storage subnet with a
# private IP address. Combined with Private DNS Zone, the storage account's
# FQDN resolves to this private IP instead of the public IP.
#
# Sub-resources available for storage: blob, file, queue, table, web, dfs
# Each requires its own private endpoint and DNS zone.
# =============================================================================

# --- Private DNS Zone for blob.core.windows.net ---

resource "azurerm_private_dns_zone" "blob" {
  name                = "privatelink.blob.core.windows.net"
  resource_group_name = azurerm_resource_group.storage.name
  tags                = local.common_tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "blob" {
  name                  = "${var.prefix}-blob-dns-link"
  resource_group_name   = azurerm_resource_group.storage.name
  private_dns_zone_name = azurerm_private_dns_zone.blob.name
  virtual_network_id    = var.vnet_id
  registration_enabled  = false
  tags                  = local.common_tags
}

# --- Private Endpoint ---

resource "azurerm_private_endpoint" "blob" {
  name                = "${var.prefix}-storage-pe-${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.storage.name
  location            = azurerm_resource_group.storage.location
  subnet_id           = var.storage_subnet_id
  tags                = local.common_tags

  private_service_connection {
    name                           = "${var.prefix}-storage-psc"
    private_connection_resource_id = azurerm_storage_account.main.id
    subresource_names              = ["blob"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "blob-dns-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.blob.id]
  }
}
