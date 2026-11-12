# =============================================================================
# AZ-305 Lab — Module 08: Data Integration
# =============================================================================
# Creates Azure Data Factory, Data Lake Storage Gen2, linked services,
# a sample pipeline, and Event Grid topic to demonstrate enterprise data
# integration patterns tested on the AZ-305 exam.
#
# AZ-305 Exam Relevance:
#   - Design data integration solutions (Data Factory, Synapse, Databricks)
#   - Design data storage solutions (Data Lake Gen2, medallion architecture)
#   - ETL vs ELT patterns and when each applies
#   - Integration Runtime types and on-premises connectivity
#   - Event-driven architectures for data processing
#   - Data governance with Microsoft Purview
#
# Cost: ~$1/day — ADF at rest is near-zero; Data Lake Standard LRS is cheap.
#        Pipeline executions and integration runtime uptime add incremental cost.
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
  storage_use_azuread = true
}

# =============================================================================
# RANDOM SUFFIX — ensures globally unique names for ADF and storage accounts
# =============================================================================

resource "random_string" "suffix" {
  length  = 6
  upper   = false
  special = false
}

# =============================================================================
# LOCAL VALUES
# =============================================================================

locals {
  common_tags = merge(var.tags, {
    Module  = "08-data-integration"
    Purpose = "AZ-305 Data Factory and Data Lake lab"
  })
  prefix_clean = replace(var.prefix, "-", "")
}

# =============================================================================
# RESOURCE GROUP
# =============================================================================

resource "azurerm_resource_group" "main" {
  name     = "${var.prefix}-mod08-dataintegration-rg"
  location = var.location
  tags     = local.common_tags

  lifecycle {
    # Non-semantic: Azure auto-adds rg-class tag for internal classification. Not a config choice.
    ignore_changes = [tags["rg-class"]]
  }
}

# =============================================================================
# AZURE DATA FACTORY
# =============================================================================
#
# AZ-305 Key Concept: Azure Data Factory Architecture
#
# ADF is a cloud-based ETL/ELT service built for:
#   - Pipelines:      Logical grouping of activities (the workflow)
#   - Activities:      Individual tasks — Copy, Data Flow, Lookup, Web, etc.
#   - Datasets:        Named views of data — point at a file, table, or API
#   - Linked Services: Connection strings + auth to external systems
#   - Integration Runtimes (IR):
#       • Azure IR      — serverless, auto-resolve region (default)
#       • Self-Hosted IR — runs on your VM/on-prem for private data sources
#       • Azure-SSIS IR  — lifts & shifts existing SSIS packages
#   - Triggers:        Schedule, tumbling window, event-based, or manual
#
# AZ-305 Key Concept: ETL vs ELT
#
#   ETL (Extract–Transform–Load):
#     Transform happens OUTSIDE the destination (in ADF compute or an IR).
#     Good for small-to-medium volumes, schema-on-write.
#
#   ELT (Extract–Load–Transform):
#     Raw data lands first; transformation happens INSIDE the destination
#     (e.g., Synapse SQL pool, Databricks, Spark).
#     Preferred in cloud because destination compute scales independently.
#     AZ-305 favors ELT for large-scale analytics workloads.
#
# AZ-305 Key Concept: Azure Synapse Analytics vs Data Factory
#
#   Synapse = ADF pipelines + Apache Spark pools + Dedicated/Serverless SQL pools
#   all in one workspace. Use Synapse when you need unified analytics; use
#   standalone ADF when you only need data movement and orchestration.
#
# AZ-305 Key Concept: When to choose each service for data movement
#
#   Azure Data Factory: Complex multi-step ETL/ELT, 90+ connectors, scheduling
#   Logic Apps:         Event-driven workflows, SaaS-to-SaaS integration, low code
#   Azure Functions:    Custom code, real-time stream transforms, sub-second triggers
#   Event Grid + Functions: Reactive patterns (file arrives → process immediately)
#
# AZ-305 Key Concept: Azure Databricks (not deployed here)
#
#   Managed Apache Spark platform for large-scale data engineering and ML.
#   Integrates with Data Lake Gen2 via ABFSS driver. ADF can orchestrate
#   Databricks notebooks as pipeline activities. Choose Databricks when you
#   need Spark-scale transformations or collaborative notebooks.
#
# =============================================================================

resource "azurerm_data_factory" "main" {
  name                = "${var.prefix}-adf-${random_string.suffix.result}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  # Managed Virtual Network restricts ADF's data movement to a Microsoft-managed
  # VNet. Managed private endpoints connect to PaaS services without public exposure.
  managed_virtual_network_enabled = true

  public_network_enabled = var.data_factory_public_network

  # System-assigned managed identity — used for RBAC-based auth to Data Lake,
  # Key Vault, and other Azure services. Eliminates stored credentials.
  identity {
    type = "SystemAssigned"
  }

  # Git configuration: none for this lab. In production, connect to Azure DevOps
  # or GitHub for version-controlled pipeline definitions (CI/CD for data pipelines).

  tags = local.common_tags
}

# --- Data Factory Diagnostic Settings ---

resource "azurerm_monitor_diagnostic_setting" "adf" {
  name               = "${var.prefix}-adf-diag"
  target_resource_id = azurerm_data_factory.main.id

  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "ActivityRuns"
  }

  enabled_log {
    category = "PipelineRuns"
  }

  enabled_log {
    category = "TriggerRuns"
  }

  enabled_metric {
    category = "AllMetrics"
  }
}

# =============================================================================
# DATA LAKE STORAGE GEN2
# =============================================================================
#
# AZ-305 Key Concept: Data Lake Gen2 Architecture
#
#   Data Lake Gen2 = Azure Blob Storage + Hierarchical Namespace (HNS).
#   HNS enables true directory operations (rename is O(1), not O(n)),
#   POSIX-style ACLs, and ABFSS driver support required by Spark/Databricks.
#
#   Always enable HNS for analytics workloads. Without it, you only get
#   flat blob storage — fine for app data, but not for data lake patterns.
#
# AZ-305 Key Concept: Medallion Architecture (Bronze → Silver → Gold)
#
#   Bronze / Raw:       Exact copy of source data, no transforms.
#                       Immutable audit trail. Partitioned by ingestion date.
#   Silver / Processed: Cleaned, deduplicated, schema-enforced.
#                       Joined across sources. Conforms to a common model.
#   Gold / Curated:     Business-level aggregates, KPIs, reporting tables.
#                       Optimized for consumption by BI tools and APIs.
#
#   This pattern appears frequently on AZ-305 as the recommended approach
#   for organizing analytical data in Azure.
#
# AZ-305 Key Concept: Data Lake Security — Defense in Depth
#
#   Layer 1: Network — Storage firewall, private endpoints, VNet service endpoints
#   Layer 2: Identity — Azure RBAC roles (Storage Blob Data Contributor, etc.)
#   Layer 3: ACLs — POSIX ACLs on directories/files for fine-grained access
#   Layer 4: Encryption — SSE with Microsoft-managed or customer-managed keys
#   Layer 5: Governance — Microsoft Purview for classification and lineage
#
#   RBAC is coarse-grained (account or container level).
#   ACLs are fine-grained (directory/file level).
#   Use RBAC for service principals; use ACLs for user/group access within a lake.
#
# AZ-305 Key Concept: Microsoft Purview (not deployed here)
#
#   Unified data governance service for discovering, classifying, and governing
#   data across on-premises, multi-cloud, and SaaS. Scans Data Lake, SQL,
#   Synapse, and 100+ sources. Provides data catalog, lineage visualization,
#   and sensitivity labels. Key for compliance-heavy AZ-305 scenarios.
#
# =============================================================================

resource "azurerm_storage_account" "datalake" {
  name                = "${local.prefix_clean}dl${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location

  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"

  # Hierarchical namespace = Data Lake Gen2. Required for POSIX ACLs,
  # ABFSS driver, and efficient directory-level operations.
  is_hns_enabled = true

  allow_nested_items_to_be_public  = var.storage_allow_public_access
  shared_access_key_enabled        = var.storage_shared_key_enabled
  public_network_access_enabled    = var.storage_public_network_access

  tags = local.common_tags
}

# --- Medallion Architecture Containers ---
# Data plane resources: created once, managed via Portal/CLI.
# With public_network_access disabled by policy, Terraform cannot refresh
# these from outside the private network on subsequent plans.

resource "azurerm_storage_data_lake_gen2_filesystem" "raw" {
  count              = var.deploy_datalake_filesystems ? 1 : 0
  name               = "raw"
  storage_account_id = azurerm_storage_account.datalake.id
}

resource "azurerm_storage_data_lake_gen2_filesystem" "processed" {
  count              = var.deploy_datalake_filesystems ? 1 : 0
  name               = "processed"
  storage_account_id = azurerm_storage_account.datalake.id
}

resource "azurerm_storage_data_lake_gen2_filesystem" "curated" {
  count              = var.deploy_datalake_filesystems ? 1 : 0
  name               = "curated"
  storage_account_id = azurerm_storage_account.datalake.id
}

# --- Data Lake Diagnostic Settings ---

resource "azurerm_monitor_diagnostic_setting" "datalake" {
  name               = "${var.prefix}-datalake-diag"
  target_resource_id = azurerm_storage_account.datalake.id

  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_metric {
    category = "Transaction"
  }
}

# =============================================================================
# DATA FACTORY — LINKED SERVICE TO DATA LAKE
# =============================================================================
# A Linked Service defines the connection to an external data store.
# Using ADF's managed identity avoids storing secrets in connection strings.
# =============================================================================

resource "azurerm_data_factory_linked_service_data_lake_storage_gen2" "datalake" {
  name            = "ls-datalake"
  data_factory_id = azurerm_data_factory.main.id

  # Connect via managed identity — the ADF system identity needs
  # "Storage Blob Data Contributor" on the Data Lake account.
  url                  = azurerm_storage_account.datalake.primary_dfs_endpoint
  use_managed_identity = true
}

# --- RBAC: Grant ADF managed identity access to the Data Lake ---

resource "azurerm_role_assignment" "adf_datalake_contributor" {
  scope                = azurerm_storage_account.datalake.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_data_factory.main.identity[0].principal_id
}

# =============================================================================
# DATA FACTORY — SAMPLE COPY PIPELINE
# =============================================================================
# Demonstrates the fundamental ADF pattern: a pipeline with a copy activity.
#
# In a real environment, this would:
#   1. Extract data from source (SQL, API, SFTP, SaaS connector)
#   2. Land it in the Bronze/raw container
#   3. Trigger downstream transforms (Data Flow, Databricks, Synapse)
#
# The pipeline JSON below creates a minimal placeholder. In production,
# pipeline definitions are version-controlled and deployed via CI/CD.
# =============================================================================

resource "azurerm_data_factory_pipeline" "sample_copy" {
  name            = "sample-copy-pipeline"
  data_factory_id = azurerm_data_factory.main.id

  description = "Sample pipeline demonstrating ETL/ELT copy pattern. In production, this would copy data from source to the raw (Bronze) container."

  # Activities are defined as JSON. This is a Wait activity placeholder.
  # A real pipeline would use Copy, DataFlow, Lookup, ForEach, etc.
  activities_json = jsonencode([
    {
      name = "WaitForDemo"
      type = "Wait"
      typeProperties = {
        waitTimeInSeconds = 5
      }
      # AZ-305 note: In a real pipeline, replace this with a Copy activity:
      #   type = "Copy"
      #   typeProperties = {
      #     source    = { type = "AzureSqlSource", sqlReaderQuery = "SELECT ..." }
      #     sink      = { type = "ParquetSink", storeSettings = { type = "AzureBlobFSWriteSettings" } }
      #     enableStaging = false
      #   }
      #
      # More complex patterns include:
      #   - ForEach: iterate over a list of tables/files
      #   - If Condition: branch logic based on Lookup results
      #   - Data Flow: visual Spark-based transformations (ADF Mapping Data Flows)
      #   - Execute Pipeline: modular composition of sub-pipelines
    }
  ])
}

# =============================================================================
# SELF-HOSTED INTEGRATION RUNTIME (COMMENTED OUT)
# =============================================================================
#
# AZ-305 Key Concept: Self-Hosted Integration Runtime
#
# A Self-Hosted IR is required when Data Factory needs to access data that is:
#   - On-premises (SQL Server, Oracle, file shares behind a corporate firewall)
#   - In a private VNet without public endpoints
#   - In another cloud (AWS S3 via private link, GCP BigQuery)
#
# How it works:
#   1. Install the IR agent on a Windows VM (on-prem or Azure)
#   2. The agent registers with ADF and opens an outbound HTTPS connection
#   3. ADF sends copy/lookup commands over that connection — no inbound ports
#   4. For HA, install on 2+ nodes and they share the registration key
#
# The resource below would create the ADF-side definition. You'd still need
# to install the agent on a VM and register it with the authentication key.
#
# resource "azurerm_data_factory_integration_runtime_self_hosted" "onprem" {
#   name            = "${var.prefix}-ir-selfhosted"
#   data_factory_id = azurerm_data_factory.main.id
#
#   description = "Self-hosted IR for on-premises data source connectivity"
#
#   # After creation, retrieve the authentication key from the portal or via:
#   #   az datafactory integration-runtime list-auth-keys \
#   #     --factory-name <adf-name> --name <ir-name> -g <rg>
#   # Install the IR agent on a VM and paste the key during setup.
# }
#
# =============================================================================

# =============================================================================
# EVENT GRID — EVENT-DRIVEN DATA PROCESSING
# =============================================================================
#
# AZ-305 Key Concept: Event-Driven Data Architecture
#
# Instead of polling for new files, Event Grid pushes notifications instantly
# when blobs are created, updated, or deleted. This enables:
#   - ADF pipeline trigger on BlobCreated → process file immediately
#   - Azure Functions subscriber → lightweight transform on arrival
#   - Logic Apps subscriber → notify team or update a catalog
#
# The System Topic captures events from the Data Lake storage account.
# In production, you'd add subscriptions routing events to ADF, Functions, etc.
# =============================================================================

resource "azurerm_eventgrid_system_topic" "datalake_events" {
  name                = "${var.prefix}-datalake-events-${random_string.suffix.result}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  source_arm_resource_id = azurerm_storage_account.datalake.id
  topic_type             = "Microsoft.Storage.StorageAccounts"

  identity {
    type = "SystemAssigned"
  }

  tags = local.common_tags
}

# --- Diagnostic settings for Event Grid System Topic ---

resource "azurerm_monitor_diagnostic_setting" "eventgrid" {
  name               = "${var.prefix}-eventgrid-diag"
  target_resource_id = azurerm_eventgrid_system_topic.datalake_events.id

  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "DeliveryFailures"
  }

  enabled_metric {
    category = "AllMetrics"
  }
}
