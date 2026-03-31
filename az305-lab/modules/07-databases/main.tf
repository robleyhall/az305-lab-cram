# =============================================================================
# AZ-305 Lab — Module 07: Database Solutions
# =============================================================================
# This module demonstrates Azure SQL Database and Azure Cosmos DB — the two
# most heavily tested database services on the AZ-305 exam. SQL alone is
# mentioned 64 times in John Savill's cram session. This lab covers:
#
#   - Azure SQL deployment models (single DB, elastic pool, managed instance)
#   - DTU vs vCore purchasing models
#   - Serverless compute tier (auto-pause, cost optimization)
#   - Azure Cosmos DB with SQL (NoSQL) API
#   - Cosmos DB consistency levels and partitioning strategy
#   - Private endpoint connectivity for SQL Server
#   - Diagnostic settings and auditing
#
# AZ-305 Exam Relevance:
#   - "Design data storage solutions" is a major exam domain
#   - Know when to choose SQL Database vs Managed Instance vs SQL on VM
#   - Understand DTU vs vCore trade-offs (frequently tested)
#   - Cosmos DB consistency levels are a favourite exam question
#   - Partitioning strategy impacts performance and cost
#
# Cost: ~$3/day (SQL Basic + Serverless when active + Elastic Pool + Cosmos
#        serverless). Run `terraform destroy` when not studying.
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
# Data Sources — current identity for Azure AD admin configuration
# -----------------------------------------------------------------------------

# Retrieve the current Azure CLI / service principal identity.
# Used to configure the SQL Server Azure AD administrator so the deploying
# user can manage databases without relying solely on SQL authentication.
data "azurerm_client_config" "current" {}

# -----------------------------------------------------------------------------
# Local values
# -----------------------------------------------------------------------------
locals {
  common_tags = merge(var.tags, {
    Module  = "07-databases"
    Purpose = "Azure SQL and Cosmos DB database services"
  })
}

# -----------------------------------------------------------------------------
# Random suffix — globally unique names for SQL Server and Cosmos DB
# -----------------------------------------------------------------------------
# SQL Server and Cosmos DB account names must be globally unique across Azure.
# A short random suffix prevents collisions across lab deployments.
resource "random_string" "suffix" {
  length  = 6
  upper   = false
  special = false
}

# -----------------------------------------------------------------------------
# Random password — SQL Server administrator password
# -----------------------------------------------------------------------------
# AZ-305 EXAM TIP: Never hard-code passwords in Terraform. Use random_password
# or integrate with Key Vault. In production, combine SQL auth with Azure AD
# auth and consider Azure AD-only authentication for zero-password scenarios.
resource "random_password" "sql_admin" {
  length  = 32
  special = true
}

# =============================================================================
# Resource Group
# =============================================================================
resource "azurerm_resource_group" "databases" {
  name     = "${var.prefix}-databases-rg-${random_string.suffix.result}"
  location = var.location
  tags     = local.common_tags

  lifecycle {
    # Non-semantic: Azure auto-adds rg-class tag for internal classification. Not a config choice.
    ignore_changes = [tags["rg-class"]]
  }
}

# =============================================================================
# AZURE SQL SERVER
# =============================================================================
# AZ-305 EXAM TOPIC: Azure SQL Deployment Models (CRITICAL — Know All Four)
# ---------------------------------------------------------------------------
# Azure offers four SQL deployment models. The exam WILL test your ability to
# choose the right one for a given scenario:
#
#   1. Azure SQL Database (Single Database) — Fully managed PaaS
#      - Per-database billing (DTU or vCore model)
#      - Best for: new cloud-native apps, single-tenant workloads
#      - Limitations: no cross-database queries, no SQL Agent, no CLR
#
#   2. Azure SQL Elastic Pool — Shared resources across databases
#      - Pool of DTUs or vCores shared by multiple databases
#      - Best for: SaaS / multi-tenant apps with variable per-tenant load
#      - Cost benefit when databases have complementary usage patterns
#
#   3. Azure SQL Managed Instance — Near 100% SQL Server compatibility
#      - VNet-integrated (deployed into your subnet)
#      - Supports: cross-database queries, SQL Agent, CLR, linked servers,
#        Service Broker, Database Mail, distributed transactions
#      - Best for: lift-and-shift of on-prem SQL Server workloads
#      - More expensive but maximum PaaS compatibility
#
#   4. SQL Server on Azure VM (IaaS) — Full OS-level control
#      - You manage the OS, patching, backups, HA
#      - Supports: everything SQL Server supports (SSIS, SSRS, SSAS, etc.)
#      - Best for: apps requiring OS access or unsupported SQL features
#      - Use Automated Patching and Automated Backup for partial management
#
# Decision tree (exam favourite):
#   Need OS access?                    → SQL on VM
#   Need SQL Agent / CLR / linked?     → Managed Instance (or VM)
#   Need cross-database queries?       → Managed Instance (or VM)
#   Multi-tenant / many small DBs?     → Elastic Pool
#   Single cloud-native database?      → SQL Database (single)
# ---------------------------------------------------------------------------

resource "azurerm_mssql_server" "main" {
  name                          = "${var.prefix}-sqlserver-${random_string.suffix.result}"
  resource_group_name           = azurerm_resource_group.databases.name
  location                      = azurerm_resource_group.databases.location
  version                       = "12.0"
  public_network_access_enabled = true # No private endpoint in cross-region deployment
  tags                          = local.common_tags

  minimum_tls_version = "1.2"

  azuread_administrator {
    login_username              = "AzureAD Admin"
    object_id                   = data.azurerm_client_config.current.object_id
    azuread_authentication_only = true
  }
}

# =============================================================================
# AZURE SQL DATABASES
# =============================================================================
# AZ-305 EXAM TOPIC: DTU vs vCore Purchasing Models (Frequently Tested)
# ---------------------------------------------------------------------------
# The exam loves asking when to use DTU vs vCore. Know these differences:
#
#   DTU (Database Transaction Unit) Model:
#     - Bundled measure of compute, I/O, and memory
#     - Simple: pick a tier (Basic/Standard/Premium) and DTU count
#     - Predictable pricing — fixed monthly cost
#     - Cannot independently scale compute vs storage
#     - Tiers: Basic (5 DTUs), Standard (10-3000 DTUs), Premium (125-4000 DTUs)
#     - Best for: simple workloads with predictable performance needs
#
#   vCore Model:
#     - Independently scale compute (vCores) and storage (GB)
#     - Flexible: choose service tier + hardware generation + vCores
#     - Service tiers: General Purpose, Business Critical, Hyperscale
#     - Supports serverless compute (auto-pause, auto-scale)
#     - Azure Hybrid Benefit — reuse existing SQL Server licenses (up to 55% savings)
#     - Best for: workloads needing fine-grained control or license reuse
#
#   When to choose which:
#     DTU → simple workloads, predictable cost, no license reuse
#     vCore → need license savings, independent scaling, or serverless
# ---------------------------------------------------------------------------

# --- SQL Database: Basic (DTU Model) ---
# Demonstrates the DTU purchasing model with the lowest tier.
# Basic tier: 5 DTUs, up to 2 GB storage, ~$5/month.
resource "azurerm_mssql_database" "basic" {
  name      = "${var.prefix}-sqldb-basic"
  server_id = azurerm_mssql_server.main.id
  tags      = local.common_tags

  # SKU "Basic" = DTU model, 5 DTUs. Cheapest tier for development and testing.
  sku_name    = "Basic"
  max_size_gb = 2

  # AZ-305 EXAM TOPIC: Backup and Restore Options
  # -----------------------------------------------------------------------
  # Azure SQL automatically creates backups:
  #   - Full backups: weekly
  #   - Differential backups: every 12-24 hours
  #   - Transaction log backups: every 5-10 minutes
  #
  # Retention options:
  #   - Short-term (PITR): 1-35 days (Basic: 1-7 days)
  #   - Long-term (LTR): up to 10 years in Azure Blob Storage
  #   - Geo-redundant backup storage for cross-region recovery
  #
  # Backup storage redundancy options:
  #   - Local (LRS), Zone (ZRS), Geo (GRS)
  #   - Basic/Standard default to GRS; premium tiers offer choice
  # -----------------------------------------------------------------------
  short_term_retention_policy {
    retention_days = 7
  }
}

# --- SQL Database: General Purpose Serverless (vCore Model) ---
# AZ-305 EXAM TOPIC: Serverless Compute Tier
# ---------------------------------------------------------------------------
# Serverless is a cost-optimization feature for intermittent workloads:
#
#   - Auto-scale: compute scales automatically within min/max vCore range
#   - Auto-pause: database pauses after a configurable idle period (min 60 min)
#     When paused, you pay ONLY for storage — compute cost drops to zero
#   - Auto-resume: first connection after pause wakes the database (~1 min delay)
#   - Billing: per-second for compute, per-GB for storage
#
#   Best for: dev/test, infrequently used apps, unpredictable workloads
#   NOT suitable for: latency-sensitive apps (auto-resume delay), steady-state
#                     workloads (provisioned compute is cheaper at high utilization)
# ---------------------------------------------------------------------------
resource "azurerm_mssql_database" "serverless" {
  name      = "${var.prefix}-sqldb-serverless"
  server_id = azurerm_mssql_server.main.id
  tags      = local.common_tags

  # GP_S_Gen5_1 = General Purpose, Serverless, Gen5 hardware, 1 max vCore
  sku_name    = "GP_S_Gen5_1"
  max_size_gb = 32

  # Serverless-specific settings
  auto_pause_delay_in_minutes = 60  # Pause after 60 min idle (minimum allowed)
  min_capacity                = 0.5 # Scale down to 0.5 vCores when quiet

  short_term_retention_policy {
    retention_days = 7
  }
}

# AZ-305 EXAM TOPIC: Hyperscale Service Tier (Know the Concepts)
# ---------------------------------------------------------------------------
# Hyperscale is NOT deployed here (expensive), but know these key facts:
#
#   - Storage up to 100 TB (other tiers max at 4 TB General Purpose / 4 TB BC)
#   - Rapid scale-out read replicas (up to 4 named replicas)
#   - Nearly instantaneous backups (snapshot-based, regardless of DB size)
#   - Fast restores (minutes, not hours) via page-server architecture
#   - Decoupled compute and storage architecture
#   - Best for: very large databases, OLTP workloads needing read scale-out
#
#   Exam scenario: "100 TB database needs fast backup and read scale-out"
#   → Answer: Hyperscale
# ---------------------------------------------------------------------------

# =============================================================================
# AZURE SQL ELASTIC POOL
# =============================================================================
# AZ-305 EXAM TOPIC: Elastic Pools for Multi-Tenant Workloads
# ---------------------------------------------------------------------------
# An elastic pool shares a fixed set of resources (DTUs or vCores) across
# multiple databases. This is cost-effective when databases have:
#
#   - Variable usage patterns (some busy, some idle at any given time)
#   - Complementary peak times (database A peaks at noon, B peaks at midnight)
#   - Low average utilization but occasional spikes
#
# Typical scenario: SaaS application with one database per tenant.
# Without pools: 100 databases × 10 DTUs = 1000 DTUs purchased.
# With pools: 100 databases sharing 200 DTUs (because they don't all peak
# simultaneously) = 80% cost savings.
#
# Pool sizing rule of thumb:
#   Pool eDTUs ≥ MAX(total avg utilization, peak of busiest DB)
# ---------------------------------------------------------------------------

resource "azurerm_mssql_elasticpool" "main" {
  name                = "${var.prefix}-sql-pool-${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.databases.name
  location            = azurerm_resource_group.databases.location
  server_name         = azurerm_mssql_server.main.name
  max_size_gb         = 4.8828125
  tags                = local.common_tags

  # BasicPool: 50 eDTUs shared across databases in the pool.
  sku {
    name     = "BasicPool"
    tier     = "Basic"
    capacity = 50
  }

  # Per-database min/max controls prevent one database from consuming all pool resources.
  per_database_settings {
    min_capacity = 0 # Databases can idle at 0 eDTUs (releases resources to pool)
    max_capacity = 5 # No single database can exceed 5 eDTUs
  }
}

# =============================================================================
# SQL SERVER FIREWALL RULES
# =============================================================================
# AZ-305 EXAM TOPIC: SQL Server Network Security Layers
# ---------------------------------------------------------------------------
# Azure SQL Server supports multiple network security layers:
#
#   1. Firewall rules (IP-based):
#      - Server-level: allow specific public IPs or IP ranges
#      - "Allow Azure services" (0.0.0.0) — lets other Azure services connect
#      - Database-level rules (configured inside the database via T-SQL)
#
#   2. Virtual Network service endpoints:
#      - Allow traffic from specific VNet subnets
#      - Traffic stays on Azure backbone but uses public endpoint
#
#   3. Private endpoints (recommended for production):
#      - Private IP in your VNet — traffic never traverses public internet
#      - Combined with "Deny public network access" for maximum security
#
#   Exam tip: Know the difference between service endpoints and private
#   endpoints. Private endpoints are more secure (private IP vs public
#   endpoint with ACL) and work across VNet peering and VPN/ExpressRoute.
# ---------------------------------------------------------------------------

# Allow Azure services — required for Azure-to-Azure connectivity
# (e.g., App Service, Azure Functions, Data Factory connecting to SQL).
# The special IP range 0.0.0.0 to 0.0.0.0 signals "allow Azure services".
# Firewall rules disabled — public_network_access is off (MCAPS policy).
# Access is only through private endpoint.
# resource "azurerm_mssql_firewall_rule" "allow_azure_services" {
#   name             = "AllowAzureServices"
#   server_id        = azurerm_mssql_server.main.id
#   start_ip_address = "0.0.0.0"
#   end_ip_address   = "0.0.0.0"
# }

# resource "azurerm_mssql_firewall_rule" "allow_client_ip" {
#   name             = "AllowLabClientIP"
#   server_id        = azurerm_mssql_server.main.id
#   start_ip_address = var.allowed_client_ip
#   end_ip_address   = var.allowed_client_ip
# }

# =============================================================================
# PRIVATE ENDPOINT FOR SQL SERVER
# =============================================================================
# AZ-305 EXAM TOPIC: Private Endpoint Pattern (Frequently Tested)
# ---------------------------------------------------------------------------
# Same three-piece pattern as Key Vault (Module 03), applied to SQL Server:
#   1. Private DNS Zone — resolves *.database.windows.net to private IP
#   2. VNet Link — connects DNS zone to VNet for resolution
#   3. Private Endpoint — NIC with private IP in database subnet
#
# For SQL Server, the subresource type is "sqlServer". Each PaaS service has
# its own subresource name and private DNS zone FQDN:
#
#   | Service        | Subresource      | Private DNS Zone                       |
#   |----------------|------------------|----------------------------------------|
#   | SQL Server     | sqlServer        | privatelink.database.windows.net       |
#   | Cosmos DB      | Sql              | privatelink.documents.azure.com        |
#   | Key Vault      | vault            | privatelink.vaultcore.azure.net        |
#   | Storage (blob) | blob             | privatelink.blob.core.windows.net      |
#   | Storage (file) | file             | privatelink.file.core.windows.net      |
#
# In production, disable public network access on the SQL Server after
# configuring the private endpoint to ensure all traffic is private.
# ---------------------------------------------------------------------------

# Private endpoint resources disabled — module deployed to eastus2 while
# foundation VNet is in eastus. Private endpoints require same-region subnet.
# Uncomment when deploying in same region as foundation.

# resource "azurerm_private_dns_zone" "sql" {
#   name                = "privatelink.database.windows.net"
#   resource_group_name = azurerm_resource_group.databases.name
#   tags                = local.common_tags
# }

# resource "azurerm_private_dns_zone_virtual_network_link" "sql" {
#   name                  = "${var.prefix}-sql-dns-link"
#   resource_group_name   = azurerm_resource_group.databases.name
#   private_dns_zone_name = azurerm_private_dns_zone.sql.name
#   virtual_network_id    = var.vnet_id
#   registration_enabled  = false
#   tags                  = local.common_tags
# }

# resource "azurerm_private_endpoint" "sql" {
#   name                = "${var.prefix}-sql-pe-${random_string.suffix.result}"
#   resource_group_name = azurerm_resource_group.databases.name
#   location            = azurerm_resource_group.databases.location
#   subnet_id           = var.database_subnet_id
#   tags                = local.common_tags
#
#   private_service_connection {
#     name                           = "${var.prefix}-sql-psc"
#     private_connection_resource_id = azurerm_mssql_server.main.id
#     subresource_names              = ["sqlServer"]
#     is_manual_connection           = false
#   }
#
#   private_dns_zone_group {
#     name                 = "sql-dns-group"
#     private_dns_zone_ids = [azurerm_private_dns_zone.sql.id]
#   }
# }

# =============================================================================
# AZURE COSMOS DB
# =============================================================================
# AZ-305 EXAM TOPIC: Cosmos DB Consistency Levels (TOP Exam Question)
# ---------------------------------------------------------------------------
# Cosmos DB offers five consistency levels, ordered from strongest to weakest.
# The exam FREQUENTLY tests your understanding of these trade-offs:
#
#   Level                  | Guarantees                                | Latency   | Throughput | Cost
#   -----------------------|-------------------------------------------|-----------|------------|------
#   Strong                 | Linearizability (reads always latest)     | Highest   | Lowest     | Highest
#   Bounded Staleness      | Reads lag by at most K versions or T time | High      | Low        | High
#   Session (default)      | Read-your-writes within a session         | Moderate  | Moderate   | Moderate
#   Consistent Prefix      | Reads never see out-of-order writes       | Low       | High       | Low
#   Eventual               | No ordering guarantees                    | Lowest    | Highest    | Lowest
#
# Key exam scenarios:
#   - "User must see their own writes immediately" → Session (default)
#   - "Financial transactions require latest data" → Strong
#   - "Reads can lag by 5 minutes but must be ordered" → Bounded Staleness
#   - "Global app, lowest latency, can tolerate stale reads" → Eventual
#   - Strong consistency is NOT available with multi-region writes
#
# Default for new accounts: Session — best balance for most applications.
# This lab uses Session consistency.
# ---------------------------------------------------------------------------
#
# AZ-305 EXAM TOPIC: Cosmos DB APIs (Know When to Use Each)
# ---------------------------------------------------------------------------
# Cosmos DB supports multiple APIs — each targets a different ecosystem:
#
#   SQL (NoSQL) API — Most commonly tested on AZ-305
#     - JSON documents, SQL-like query language
#     - Best for: new applications, maximum Cosmos DB feature support
#     - This lab uses the SQL API
#
#   MongoDB API — Wire-compatible with MongoDB protocol
#     - Best for: migrating existing MongoDB applications
#     - Use existing MongoDB drivers and tools
#
#   Cassandra API — Wire-compatible with Apache Cassandra
#     - Best for: migrating Cassandra workloads needing global distribution
#
#   Gremlin API — Graph database
#     - Best for: social networks, recommendation engines, knowledge graphs
#
#   Table API — Key-value store (Azure Table Storage compatible)
#     - Best for: migrating from Azure Table Storage with global distribution
#
# Exam tip: The API is chosen at account creation and CANNOT be changed later.
# ---------------------------------------------------------------------------
#
# AZ-305 EXAM TOPIC: Cosmos DB Partitioning Strategy
# ---------------------------------------------------------------------------
# Choosing the right partition key is CRITICAL for performance and cost:
#
#   Good partition key properties:
#     - High cardinality (many distinct values) — distributes data evenly
#     - Frequently used in WHERE clauses — enables efficient queries
#     - Evenly distributes storage — no "hot" partitions
#     - Evenly distributes throughput — no partition-level throttling
#
#   Examples:
#     - E-commerce: /customerId (if customers have similar data volumes)
#     - IoT: /deviceId (each device generates similar amounts of data)
#     - Multi-tenant: /tenantId (each tenant is a natural partition)
#
#   Anti-patterns:
#     - Low cardinality keys (e.g., /status with only 3 values)
#     - Monotonically increasing keys (e.g., /timestamp — creates hot partitions)
#     - Keys not used in queries (forces cross-partition queries)
#
# This lab uses /category as the partition key for the items container.
# ---------------------------------------------------------------------------
#
# AZ-305 EXAM TOPIC: Cosmos DB Multi-Region Writes
# ---------------------------------------------------------------------------
# Cosmos DB supports two replication modes:
#
#   Single-region writes (default):
#     - One write region, multiple read regions
#     - Automatic failover to a read region if write region goes down
#     - Lower cost, simpler conflict resolution
#
#   Multi-region writes:
#     - All regions accept writes simultaneously
#     - Lower write latency for globally distributed users
#     - Requires conflict resolution policy (Last-Writer-Wins or custom)
#     - Higher RU cost (multi-master replication overhead)
#     - Strong consistency NOT available with multi-region writes
#
# This lab uses single-region for cost savings. In production, enable
# multi-region writes for global applications requiring low write latency.
# ---------------------------------------------------------------------------

resource "azurerm_cosmosdb_account" "main" {
  name                             = "${var.prefix}-cosmos-${random_string.suffix.result}"
  resource_group_name              = azurerm_resource_group.databases.name
  location                         = azurerm_resource_group.databases.location
  offer_type                       = "Standard"
  kind                             = "GlobalDocumentDB"
  local_authentication_disabled    = true # MCAPS policy enforces Entra-only auth
  tags                             = local.common_tags

  # Session consistency — the default and most commonly tested on AZ-305.
  # Provides read-your-writes guarantee within a session (client token).
  consistency_policy {
    consistency_level = "Session"
  }

  # Single geo-location for cost savings. In production, add additional
  # geo_location blocks for multi-region replication (automatic failover).
  geo_location {
    location          = azurerm_resource_group.databases.location
    failover_priority = 0
    zone_redundant    = false
  }

  # Serverless capacity mode — pay only for RUs consumed per request.
  # No pre-provisioned throughput means zero cost when idle.
  # NOTE: Serverless is incompatible with free_tier_enabled and multi-region writes.
  # For a free tier lab, remove this capability block and set free_tier_enabled = true
  # (limited to one free-tier account per subscription).
  capabilities {
    name = "EnableServerless"
  }
}

# --- Cosmos DB SQL Database ---
resource "azurerm_cosmosdb_sql_database" "main" {
  name                = "${var.prefix}-cosmosdb"
  resource_group_name = azurerm_resource_group.databases.name
  account_name        = azurerm_cosmosdb_account.main.name
  # No throughput setting — serverless mode uses per-request billing.
}

# --- Cosmos DB SQL Container ---
# Demonstrates partitioning — the most critical Cosmos DB design decision.
resource "azurerm_cosmosdb_sql_container" "items" {
  name                = "items"
  resource_group_name = azurerm_resource_group.databases.name
  account_name        = azurerm_cosmosdb_account.main.name
  database_name       = azurerm_cosmosdb_sql_database.main.name

  # Partition key: /category — queries filtered by category execute within
  # a single logical partition (efficient). Cross-partition queries are more
  # expensive and should be minimised in production.
  partition_key_paths = ["/category"]

  # No throughput — inherited from serverless account settings.
}

# =============================================================================
# SQL SERVER AUDITING
# =============================================================================
# AZ-305 EXAM TOPIC: Transparent Data Encryption (TDE) and Always Encrypted
# ---------------------------------------------------------------------------
# TDE (Transparent Data Encryption):
#   - Encrypts data at rest (data files, log files, backups)
#   - Enabled by default on all Azure SQL databases
#   - Uses service-managed keys by default (Microsoft manages rotation)
#   - Can use customer-managed keys (CMK) via Key Vault for compliance
#   - TDE protects against physical theft of storage media
#
# Always Encrypted:
#   - Client-side encryption: data is encrypted BEFORE leaving the application
#   - SQL Server never sees plaintext — even DBAs cannot read encrypted columns
#   - Best for: PII, credit card numbers, SSNs — data that even DBAs shouldn't see
#   - Requires application changes (column encryption key in app config)
#
# Dynamic Data Masking:
#   - Masks data in query results (e.g., shows "XXXX-1234" for credit cards)
#   - Does NOT encrypt data at rest — cosmetic protection for non-privileged users
#   - Useful for: dev/test access to production-like data
# ---------------------------------------------------------------------------

# Enable SQL Server extended auditing to Azure Monitor.
# This captures all database operations for compliance and security review.
resource "azurerm_mssql_server_extended_auditing_policy" "main" {
  server_id              = azurerm_mssql_server.main.id
  log_monitoring_enabled = true
}

# =============================================================================
# DIAGNOSTIC SETTINGS — Route audit and telemetry to Log Analytics
# =============================================================================
# AZ-305 EXAM TOPIC: Geo-Replication and Failover Groups
# ---------------------------------------------------------------------------
# Azure SQL supports two HA/DR mechanisms (know the differences!):
#
#   Active Geo-Replication:
#     - Up to 4 readable secondary databases in any Azure region
#     - Manual failover only (application-managed)
#     - Per-database configuration
#     - Best for: read scale-out, ad-hoc DR for individual databases
#
#   Auto-Failover Groups:
#     - Group of databases that fail over together as a unit
#     - Automatic failover with grace period (configurable)
#     - Provides read-write and read-only listener endpoints
#     - Application reconnects automatically via listener DNS
#     - Best for: production DR with minimal application changes
#
#   Exam scenario: "Multiple databases must fail over together automatically"
#   → Answer: Auto-Failover Group (not active geo-replication)
# ---------------------------------------------------------------------------

# SQL Server audit logs → Log Analytics
# Targets the master database to capture server-level audit events.
resource "azurerm_monitor_diagnostic_setting" "sql_audit" {
  name                       = "${var.prefix}-sql-audit-diag"
  target_resource_id         = "${azurerm_mssql_server.main.id}/databases/master"
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "SQLSecurityAuditEvents"
  }

  enabled_metric {
    category = "AllMetrics"
  }

  lifecycle {
    # Non-semantic: Azure expands AllMetrics into individual category names. Representational, not config.
    ignore_changes = [enabled_metric]
  }

  depends_on = [azurerm_mssql_server_extended_auditing_policy.main]
}

# Cosmos DB telemetry → Log Analytics
# Captures data-plane requests and query performance metrics for
# troubleshooting and optimisation.
resource "azurerm_monitor_diagnostic_setting" "cosmos" {
  name                       = "${var.prefix}-cosmos-diag"
  target_resource_id         = azurerm_cosmosdb_account.main.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "DataPlaneRequests"
  }

  enabled_log {
    category = "QueryRuntimeStatistics"
  }

  enabled_metric {
    category = "AllMetrics"
  }

  lifecycle {
    # Non-semantic: Azure expands AllMetrics into individual category names. Representational, not config.
    ignore_changes = [enabled_metric]
  }
}

# =============================================================================
# AZ-305 EXAM TOPIC: SQL Database vs SQL Managed Instance — Decision Guide
# =============================================================================
# Use this decision tree when the exam presents a migration scenario:
#
#   ┌─ Need SSIS / SSRS / SSAS?
#   │  YES → SQL Server on VM (IaaS)
#   │
#   ├─ Need SQL Agent / CLR / linked servers / Service Broker?
#   │  YES → SQL Managed Instance
#   │
#   ├─ Need cross-database queries / distributed transactions?
#   │  YES → SQL Managed Instance
#   │
#   ├─ Migrating many databases with variable workloads?
#   │  YES → Elastic Pool (on SQL Database)
#   │
#   ├─ Single database, cloud-native app?
#   │  YES → SQL Database (single DB)
#   │
#   └─ Need maximum compatibility with minimal refactoring?
#      YES → SQL Managed Instance (then consider Azure Data Migration Service)
#
# Cost comparison (approximate):
#   SQL Database Basic    ~$5/month    (5 DTUs, 2 GB)
#   SQL Database GP S1    ~$15/month   (10 DTUs, 250 GB)
#   SQL Managed Instance  ~$350/month  (4 vCores, GP)
#   SQL on VM             ~$200/month  (B2ms VM + license)
# =============================================================================
