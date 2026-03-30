# =============================================================================
# AZ-305 Lab — Module 09: Compute Solutions
# =============================================================================
# CRITICAL EXAM DOMAIN: Design Infrastructure Solutions (30–35% of AZ-305)
#
# This module demonstrates the full spectrum of Azure compute options — the
# single most important topic area on the AZ-305 exam. Every resource here
# maps to a decision-tree question: "Given this scenario, which compute
# service should the architect recommend?"
#
# Creates:
#   - Linux Virtual Machine (IaaS)        — lift-and-shift, full OS control
#   - App Service / Web App (PaaS)         — managed web hosting platform
#   - Azure Container Instance (ACI)       — single-container, serverless
#   - Azure Container Registry (ACR)       — private Docker image registry
#   - Azure Function App (Serverless)      — event-driven, per-execution billing
#   - Azure Batch Account                  — large-scale parallel / HPC workloads
#
# AZ-305 Exam Relevance:
#   - Design compute solutions (VM selection, App Service, containers, serverless)
#   - Choose the right compute service for each scenario
#   - Understand scaling, availability, and cost trade-offs
#   - Container strategies: ACI vs AKS vs App Service containers
#   - Serverless patterns: Functions, Logic Apps, Event Grid
#
# Estimated Cost: ~$3.50/day (~$105/month)
#   - VM Standard_B1s       ≈ $0.30/day (with auto-shutdown savings)
#   - App Service B1        ≈ $0.44/day
#   - ACI nginx (0.5 vCPU)  ≈ $0.30/day
#   - ACR Basic             ≈ $0.17/day
#   - Function App (Y1)     ≈ $0.00/day (free grant covers lab usage)
#   - Batch Account         ≈ $0.00/day (account is free; pools cost extra)
#   - Storage accounts (x3) ≈ $0.10/day
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
      version = "~> 3.5"
    }
  }
}

provider "azurerm" {
  features {}
  storage_use_azuread = true
}

# --- Data Sources — reference resources from module 00-foundation ---

data "azurerm_resource_group" "foundation" {
  name = var.foundation_resource_group_name
}

data "azurerm_subscription" "current" {}
data "azurerm_client_config" "current" {}

# --- Local Values ---

locals {
  common_tags = merge(var.tags, {
    Module  = "09-compute"
    Purpose = "Compute solutions demonstration"
  })
  # Storage account names: lowercase alphanumeric only (no hyphens)
  prefix_clean = replace(var.prefix, "-", "")
}

# --- Random Suffix for Globally Unique Names ---
# Used for: web app, function app, ACR, batch account, storage accounts

resource "random_string" "suffix" {
  length  = 6
  lower   = true
  upper   = false
  special = false
  numeric = true
}

# =============================================================================
# RESOURCE GROUP
# =============================================================================
# Each lab module creates its own resource group for isolation and easy cleanup.

resource "azurerm_resource_group" "compute" {
  name     = "${var.prefix}-compute-rg"
  location = var.location
  tags     = local.common_tags
}

# =============================================================================
# SSH KEY GENERATION
# =============================================================================
# Generate an SSH key pair for the Linux VM. In production you would use an
# existing key pair stored in Azure Key Vault. For lab simplicity we generate
# one with tls_private_key. Override with var.admin_ssh_public_key if desired.
# =============================================================================

resource "tls_private_key" "ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# =============================================================================
# VIRTUAL MACHINE (IaaS)
# =============================================================================
# AZ-305 Key Concept: Azure Compute Decision Tree
#
# Use VMs (IaaS) when you need:
#   - Full control over the OS and runtime environment
#   - Lift-and-shift migration of on-premises workloads
#   - Custom software that cannot run on PaaS
#   - Specific OS configurations or kernel modules
#   - Legacy applications that require specific OS versions
#
# VM Sizing Families (EXAM FAVORITE):
#   B-series  — Burstable. Low-cost dev/test. CPU credits accumulate during idle.
#   D-series  — General purpose. Balanced CPU/memory for production workloads.
#   E-series  — Memory optimized. SAP HANA, large caches, in-memory analytics.
#   F-series  — Compute optimized. Batch processing, gaming servers, modeling.
#   L-series  — Storage optimized. Big data, SQL/NoSQL databases, warehousing.
#   M-series  — Memory optimized (extreme). SAP HANA large instances.
#   N-series  — GPU enabled. ML training/inference, rendering, HPC visualization.
#   H-series  — High performance compute. Fluid dynamics, finite element analysis.
#
# Exam Tips:
#   - "s" suffix = Premium SSD support (e.g., Standard_D2s_v5)
#   - "v5" = latest generation with best price/performance
#   - Know memory-to-CPU ratios per series for sizing questions
#   - Availability Sets: Fault Domains + Update Domains (99.95% SLA)
#   - Availability Zones: physically separate datacenters (99.99% SLA)
#   - VMSS: auto-scaling groups of identical VMs
# =============================================================================

# --- Network Interface for VM ---

resource "azurerm_network_interface" "vm" {
  name                = "${var.prefix}-nic-vm-linux"
  location            = azurerm_resource_group.compute.location
  resource_group_name = azurerm_resource_group.compute.name
  tags                = local.common_tags

  ip_configuration {
    name                          = "internal"
    subnet_id                     = var.compute_subnet_id
    private_ip_address_allocation = "Dynamic"
  }
}

# --- Storage Account for Boot Diagnostics ---

resource "azurerm_storage_account" "bootdiag" {
  name                     = "${local.prefix_clean}bootdiag${random_string.suffix.result}"
  location                 = azurerm_resource_group.compute.location
  resource_group_name      = azurerm_resource_group.compute.name
  account_tier             = "Standard"
  account_replication_type = "LRS"
  shared_access_key_enabled = false
  tags                     = local.common_tags
}

# --- Linux Virtual Machine ---

resource "azurerm_linux_virtual_machine" "main" {
  name                = "${var.prefix}-vm-linux"
  location            = azurerm_resource_group.compute.location
  resource_group_name = azurerm_resource_group.compute.name
  size                = var.vm_size
  admin_username      = "azureadmin"
  tags                = local.common_tags

  network_interface_ids = [azurerm_network_interface.vm.id]

  # System-assigned Managed Identity — no passwords or service principal secrets
  # AZ-305 Exam Tip: Always prefer managed identities over stored credentials.
  # System-assigned is tied to the resource lifecycle; User-assigned is shared.
  identity {
    type = "SystemAssigned"
  }

  admin_ssh_key {
    username   = "azureadmin"
    public_key = var.admin_ssh_public_key != "" ? var.admin_ssh_public_key : tls_private_key.ssh.public_key_openssh
  }

  os_disk {
    name                 = "${var.prefix}-osdisk-vm-linux"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"

    # AZ-305 Exam Tip: Managed Disk types —
    #   Standard HDD (Standard_LRS)    — dev/test, backup, infrequent access
    #   Standard SSD (StandardSSD_LRS) — web servers, light production
    #   Premium SSD (Premium_LRS)      — production, IO-intensive workloads
    #   Premium SSD v2                 — granular IOPS/throughput tuning
    #   Ultra Disk                     — sub-ms latency, SAP HANA, tier-1 DBs
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  # Boot diagnostics captures serial console output and screenshots.
  # Essential for debugging VM boot failures when RDP/SSH is unavailable.
  boot_diagnostics {
    storage_account_uri = azurerm_storage_account.bootdiag.primary_blob_endpoint
  }
}

# --- Auto-Shutdown Schedule ---
# AZ-305 Cost Optimization: Auto-shutdown reduces compute costs for non-production
# VMs. Common exam scenario for cost management and governance policies.

resource "azurerm_dev_test_global_vm_shutdown_schedule" "vm" {
  virtual_machine_id    = azurerm_linux_virtual_machine.main.id
  location              = azurerm_resource_group.compute.location
  enabled               = true
  daily_recurrence_time = "2200"
  timezone              = "UTC"

  notification_settings {
    enabled = false
  }
}

# =============================================================================
# APP SERVICE (PaaS)
# =============================================================================
# AZ-305 Key Concept: App Service is Azure's primary PaaS compute platform.
#
# App Service Plans & Pricing Tiers (CRITICAL EXAM TOPIC):
#   Free (F1)      — 60 CPU min/day, 1 GB RAM, no custom domain/SSL
#   Shared (D1)    — 240 CPU min/day, custom domains, no scale-out
#   Basic (B1-B3)  — Dedicated VMs, manual scale (3 instances), custom SSL
#   Standard (S1-S3)  — Auto-scale, deployment slots, VNet integration, 10 inst.
#   Premium v3 (P1v3-P3v3) — Enhanced perf, 30 instances, zone redundancy
#   Isolated v2 (I1v2-I6v2) — App Service Environment (ASE), full VNet isolation
#
# Feature Availability by Tier (EXAM FAVORITES):
#   Always On            → Basic and above (B1+)
#   Custom domains/SSL   → Basic and above (B1+)
#   Deployment slots     → Standard and above (S1+)
#   Auto-scale rules     → Standard and above (S1+)
#   VNet integration     → Standard and above (S1+), regional integration
#   Hybrid Connections   → Standard and above (S1+)
#   Private Endpoints    → Premium and above (P1v3+) or ASE
#   ASE (full isolation) → Isolated tier only
#
# Scale Out vs Scale Up:
#   Scale Up   = change SKU (B1 → S1). More CPU/memory per instance.
#   Scale Out  = add instances (1 → 3). Horizontal scaling.
#   Auto-scale = automatic scale out on metrics (CPU %, HTTP queue length, etc.)
#
# Exam Pattern:
#   "The app needs deployment slots for blue-green deployments"
#     → Standard tier or higher (S1+)
#   "The app must be isolated in a private VNet with no shared infrastructure"
#     → Isolated tier (App Service Environment v3)
#   "The app needs to scale to 20 instances based on CPU utilization"
#     → Premium v3 (supports up to 30 instances with auto-scale)
# =============================================================================

# --- App Service Plan (Linux, Basic B1) ---

resource "azurerm_service_plan" "webapp" {
  name                = "${var.prefix}-asp"
  location            = azurerm_resource_group.compute.location
  resource_group_name = azurerm_resource_group.compute.name
  os_type             = "Linux"
  sku_name            = "B1"
  tags                = local.common_tags
}

# --- Web App (Linux, Node.js 20 LTS) ---

resource "azurerm_linux_web_app" "main" {
  name                = "${var.prefix}-webapp-${random_string.suffix.result}"
  location            = azurerm_resource_group.compute.location
  resource_group_name = azurerm_resource_group.compute.name
  service_plan_id     = azurerm_service_plan.webapp.id
  https_only          = true
  tags                = local.common_tags

  identity {
    type = "SystemAssigned"
  }

  site_config {
    always_on = true # Supported on Basic (B1) and above

    application_stack {
      node_version = "20-lts"
    }
  }

  # App Settings are exposed as environment variables at runtime.
  # AZ-305 Exam Tip: For secrets, use Key Vault references:
  #   @Microsoft.KeyVault(SecretUri=https://myvault.vault.azure.net/secrets/mysecret)
  # This avoids storing secrets in App Settings directly.
  app_settings = {
    "WEBSITE_NODE_DEFAULT_VERSION"   = "~20"
    "SCM_DO_BUILD_DURING_DEPLOYMENT" = "true"
    "ENVIRONMENT"                    = "lab"
    "MODULE"                         = "09-compute"
  }

  logs {
    http_logs {
      file_system {
        retention_in_days = 7
        retention_in_mb   = 35
      }
    }
    application_logs {
      file_system_level = "Information"
    }
  }
}

# --- Web App Diagnostic Setting → Log Analytics ---

resource "azurerm_monitor_diagnostic_setting" "webapp" {
  name                       = "${var.prefix}-webapp-diag"
  target_resource_id         = azurerm_linux_web_app.main.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "AppServiceHTTPLogs"
  }

  enabled_log {
    category = "AppServiceConsoleLogs"
  }

  enabled_log {
    category = "AppServiceAppLogs"
  }

  enabled_metric {
    category = "AllMetrics"
  }
}

# =============================================================================
# AZURE CONTAINER INSTANCE (ACI)
# =============================================================================
# AZ-305 Key Concept: Container Compute Options Comparison
#
# ACI (Azure Container Instances):
#   - Single container or small container group (pod-like)
#   - No orchestration, no cluster management overhead
#   - Per-second billing on vCPU and memory consumed
#   - Fast startup (~30 seconds vs minutes for VMs)
#   - Ideal for: batch jobs, CI/CD build agents, quick demos, burstable tasks
#   - Supports Linux and Windows containers
#   - Can mount Azure Files shares for persistent storage
#   - VNet integration via subnet delegation
#
# AKS (Azure Kubernetes Service) — NOT deployed here (too expensive for lab):
#   - Full Kubernetes orchestration with managed control plane
#   - Node pools: system pool (K8s services) + user pools (workloads)
#   - Auto-scaling: cluster autoscaler + Horizontal Pod Autoscaler (HPA)
#   - RBAC: Kubernetes RBAC + Azure AD integration
#   - Networking models: kubenet (basic) vs Azure CNI (advanced)
#   - Ingress controllers, service mesh (Istio, Linkerd)
#   - Ideal for: microservices architectures, complex multi-container apps
#   - Exam Tip: Know when AKS is overkill vs when it's the right choice
#     → 1-2 containers, simple lifecycle? → ACI
#     → 10+ services, service discovery, rolling updates? → AKS
#
# App Service for Containers:
#   - Run custom Docker images on App Service platform
#   - Same scaling and management as regular App Service
#   - Ideal for: teams already using App Service who want container packaging
#   - Simpler operations than AKS, less flexibility
#
# Exam Scenario Patterns:
#   "Run a batch job nightly that processes files from Storage"
#     → ACI (simple, no long-running infra, per-second billing)
#   "20 microservices with complex service-to-service communication"
#     → AKS (orchestration, service discovery, ingress routing needed)
#   "Containerized web app with minimal operational overhead"
#     → App Service for Containers (PaaS simplicity, built-in SSL/domains)
#   "Run a sidecar container alongside the main app container"
#     → ACI container group or AKS pod (both support multi-container)
# =============================================================================

resource "azurerm_container_group" "main" {
  name                = "${var.prefix}-aci"
  location            = azurerm_resource_group.compute.location
  resource_group_name = azurerm_resource_group.compute.name
  os_type             = "Linux"
  ip_address_type     = "Public"
  tags                = local.common_tags

  container {
    name   = "nginx"
    image  = "nginx:latest"
    cpu    = "0.5"
    memory = "0.5"

    ports {
      port     = 80
      protocol = "TCP"
    }
  }

  # AZ-305 Exam Tip: ACI container groups support multiple containers sharing
  # localhost networking and lifecycle — analogous to a Kubernetes pod.
  # Add sidecar containers for logging, monitoring, or reverse proxying.
}

# =============================================================================
# AZURE CONTAINER REGISTRY (ACR)
# =============================================================================
# AZ-305 Key Concept: ACR stores and manages private container images.
#
# ACR Tiers:
#   Basic    — 10 GB storage, 2 webhooks, limited throughput
#   Standard — 100 GB storage, 10 webhooks, better throughput
#   Premium  — 500 GB storage, 500 webhooks, plus:
#              • Geo-replication (replicate images to multiple regions)
#              • Private Link / Private Endpoints
#              • Content Trust (Docker Content Trust / Notary)
#              • Customer-managed encryption keys
#              • Repository-scoped tokens
#
# Key Features (exam topics):
#   - ACR Tasks: build container images in Azure (no local Docker needed)
#   - Geo-replication (Premium): low-latency pulls in each deployment region
#   - Managed Identity integration: AKS/ACI/App Service pull without passwords
#   - Vulnerability scanning: Microsoft Defender for Containers
#
# Exam Pattern:
#   "Container images must be replicated to DR region" → ACR Premium
#   "Only signed images may be deployed to production" → Content Trust (Premium)
#   "AKS must pull images without storing credentials" → Managed Identity + ACR
# =============================================================================

resource "azurerm_container_registry" "main" {
  name                = "${local.prefix_clean}acr${random_string.suffix.result}"
  location            = azurerm_resource_group.compute.location
  resource_group_name = azurerm_resource_group.compute.name
  sku                 = "Basic"
  admin_enabled       = true # Lab only — in production, use managed identities for pulls
  tags                = local.common_tags
}

# =============================================================================
# AZURE FUNCTION APP (Serverless)
# =============================================================================
# AZ-305 Key Concept: Serverless Compute
#
# Functions Hosting Plans (CRITICAL EXAM TOPIC):
#
#   Consumption (Y1):
#     - True serverless: auto-scales from 0, pay per execution
#     - 5-minute default timeout (configurable up to 10 min)
#     - Cold start: 1–10+ seconds after idle (~5 min timeout)
#     - 1.5 GB memory per instance
#     - Free grant: 1M executions + 400,000 GB-s per month
#     - Best for: sporadic/unpredictable traffic, event processing
#
#   Premium (EP1-EP3):
#     - Pre-warmed instances eliminate cold starts
#     - VNet integration for private connectivity
#     - Unlimited execution duration
#     - Up to 14 GB memory per instance
#     - KEDA-based auto-scaling
#     - Best for: latency-sensitive APIs, VNet-connected workloads
#
#   Dedicated (App Service Plan):
#     - Runs on existing App Service infrastructure
#     - Always-on, no cold start, predictable billing
#     - Use existing underutilized App Service Plans
#     - Best for: long-running functions, predictable load
#
# Durable Functions (EXAM TOPIC):
#   - Stateful workflows built on top of Azure Functions
#   - Patterns: Function chaining, Fan-out/fan-in, Async HTTP API,
#     Monitor, Human interaction (approval workflows)
#   - Exam Scenario: "Implement a multi-step approval workflow"
#     → Durable Functions with Human Interaction pattern
#   - Exam Scenario: "Process 10,000 items in parallel, aggregate results"
#     → Durable Functions with Fan-out/fan-in pattern
#
# Cold Start Implications (EXAM FAVORITE):
#   - Consumption plan: app unloads after ~5 min idle
#   - First request after cold start: 1–10+ seconds latency
#   - Mitigation strategies:
#     • Premium plan with pre-warmed instances
#     • Keep-alive ping (Timer trigger every 4 min)
#     • Dedicated plan with Always On
#   - Exam Scenario: "API must respond in <200ms at all times"
#     → Premium plan or Dedicated plan (NOT Consumption)
# =============================================================================

# --- Storage Account for Function App ---
# Every Azure Function requires a linked storage account for triggers,
# bindings, function code storage, and internal state management.

resource "azurerm_storage_account" "func" {
  name                     = "${local.prefix_clean}funcsa${random_string.suffix.result}"
  location                 = azurerm_resource_group.compute.location
  resource_group_name      = azurerm_resource_group.compute.name
  account_tier             = "Standard"
  account_replication_type = "LRS"
  shared_access_key_enabled = false
  tags                     = local.common_tags
}

# --- Application Insights for Function App ---
# Deep telemetry: request tracing, dependency tracking, exceptions, live metrics.
# Connected to the centralized Log Analytics workspace.

resource "azurerm_application_insights" "func" {
  name                = "${var.prefix}-func-appinsights"
  location            = azurerm_resource_group.compute.location
  resource_group_name = azurerm_resource_group.compute.name
  workspace_id        = var.log_analytics_workspace_id
  application_type    = "other"
  tags                = local.common_tags
}

# --- Consumption Plan (Y1) ---

resource "azurerm_service_plan" "func" {
  name                = "${var.prefix}-func-asp"
  location            = azurerm_resource_group.compute.location
  resource_group_name = azurerm_resource_group.compute.name
  os_type             = "Linux"
  sku_name            = "Y1"
  tags                = local.common_tags
}

# --- Function App (Python 3.11 on Consumption) ---

resource "azurerm_linux_function_app" "main" {
  name                       = "${var.prefix}-func-${random_string.suffix.result}"
  location                   = azurerm_resource_group.compute.location
  resource_group_name        = azurerm_resource_group.compute.name
  service_plan_id            = azurerm_service_plan.func.id
  storage_account_name       = azurerm_storage_account.func.name
  storage_account_access_key = azurerm_storage_account.func.primary_access_key
  tags                       = local.common_tags

  identity {
    type = "SystemAssigned"
  }

  site_config {
    application_stack {
      python_version = "3.11"
    }

    application_insights_connection_string = azurerm_application_insights.func.connection_string
    application_insights_key               = azurerm_application_insights.func.instrumentation_key
  }

  app_settings = {
    "FUNCTIONS_WORKER_RUNTIME"       = "python"
    "AzureWebJobsFeatureFlags"       = "EnableWorkerIndexing"
    "BUILD_FLAGS"                    = "UseExpressBuild"
    "ENABLE_ORYX_BUILD"              = "true"
    "SCM_DO_BUILD_DURING_DEPLOYMENT" = "1"
  }
}

# =============================================================================
# AZURE BATCH ACCOUNT
# =============================================================================
# AZ-305 Key Concept: Azure Batch — Large-Scale Parallel & HPC Workloads
#
# Architecture:
#   Batch Account → Pool(s) → Job(s) → Task(s)
#
#   Pool: collection of compute nodes (VMs) that execute tasks
#     - Dedicated VMs (guaranteed capacity) or Spot VMs (up to 80% savings)
#     - Auto-scale formula based on pending tasks or schedule
#     - Custom VM images or Azure Marketplace images
#     - Start tasks for node initialization (install software, pull data)
#
#   Job: logical grouping of tasks with scheduling policies
#     - Job Manager task: coordinates other tasks
#     - Job Preparation/Release tasks: per-node setup and cleanup
#     - Priority and constraints (max wall clock, max retries)
#
#   Task: unit of work — a command line, script, or container
#     - Resource files: input data staged from Azure Storage
#     - Output files: results uploaded to Azure Storage
#     - Multi-instance tasks: MPI workloads across multiple nodes
#     - Task dependencies: DAG-style execution ordering
#
# When to Use Azure Batch:
#   - Video transcoding / media rendering (large file processing)
#   - Financial risk modeling / Monte Carlo simulations
#   - Genomics sequencing / bioinformatics pipelines
#   - Image processing / OCR at scale
#   - Any embarrassingly parallel workload
#
# Exam Scenarios:
#   "Process 10,000 images daily, each taking 2 min on a single core"
#     → Azure Batch with auto-scaling pool, Spot VMs for cost savings
#   "Run MPI-based fluid dynamics across 100 nodes with InfiniBand"
#     → Azure Batch with H-series VMs, multi-instance tasks
#   "Render a feature film's visual effects across hundreds of GPUs"
#     → Azure Batch with N-series VMs, custom rendering software image
#
# Cost: The Batch account itself is FREE. You pay for the VMs in pools,
# storage for input/output, and egress. No pools deployed in this lab to
# keep costs at zero.
# =============================================================================

# --- Storage Account for Batch (auto-storage) ---

resource "azurerm_storage_account" "batch" {
  name                     = "${local.prefix_clean}batchsa${random_string.suffix.result}"
  location                 = azurerm_resource_group.compute.location
  resource_group_name      = azurerm_resource_group.compute.name
  account_tier             = "Standard"
  account_replication_type = "LRS"
  shared_access_key_enabled = false
  tags                     = local.common_tags
}

# --- Batch Account ---

resource "azurerm_batch_account" "main" {
  name                                = "${local.prefix_clean}batch${random_string.suffix.result}"
  location                            = azurerm_resource_group.compute.location
  resource_group_name                 = azurerm_resource_group.compute.name
  storage_account_id                  = azurerm_storage_account.batch.id
  storage_account_authentication_mode = "StorageKeys"
  tags                                = local.common_tags

  # Pool Allocation Modes (exam topic):
  #   Batch Service (default): Microsoft manages VM lifecycle in Batch infra
  #   User Subscription: VMs created in YOUR subscription — more control over
  #     networking, custom images, and quotas. Requires Key Vault for VM creds.
  #
  # No pools are created here to avoid ongoing compute costs. In a real scenario
  # you would define azurerm_batch_pool resources with:
  #   - vm_size (e.g., "Standard_D2s_v5")
  #   - node_count or auto_scale formula
  #   - start_task for node initialization
  #   - container_configuration for Docker-based tasks
}

# =============================================================================
# AZ-305 COMPUTE DECISION TREE — MASTER REFERENCE
# =============================================================================
#
# ┌─ "I need full OS control or must run legacy / unmodified software"
# │   └─► Virtual Machines (IaaS)
# │       ├─ Single VM with Availability Zone → 99.99% SLA
# │       ├─ Availability Set (FD+UD) → 99.95% SLA
# │       └─ VM Scale Set (VMSS) → auto-scale identical VMs
# │
# ├─ "I need to host a web app or REST API with minimal ops"
# │   └─► App Service (PaaS)
# │       ├─ Code deployment → Linux/Windows App Service
# │       ├─ Container deployment → App Service for Containers
# │       └─ Need full VNet isolation → App Service Environment (ASEv3)
# │
# ├─ "I need to run containers without managing infrastructure"
# │   ├─ Simple (1–5 containers, short-lived or steady-state)
# │   │   └─► Azure Container Instances (ACI)
# │   └─ Complex (microservices, orchestration, service mesh, 10+ services)
# │       └─► Azure Kubernetes Service (AKS)
# │
# ├─ "I need code to run only when triggered by events"
# │   └─► Azure Functions (Serverless)
# │       ├─ Stateless, short-duration → Regular Functions (Consumption)
# │       ├─ Low latency, no cold starts → Functions (Premium)
# │       └─ Stateful multi-step workflow → Durable Functions
# │
# ├─ "I need to process thousands of parallel tasks (HPC / batch)"
# │   └─► Azure Batch
# │       ├─ Cost-sensitive → Spot VMs (up to 80% savings)
# │       └─ MPI / tightly coupled → H-series with InfiniBand
# │
# └─ "I need to run background jobs on a schedule"
#     ├─ Simple timer → Azure Functions with Timer trigger
#     ├─ Complex workflow → Logic Apps or Durable Functions
#     └─ Massive parallel → Azure Batch with scheduled jobs
#
# KEY EXAM SCENARIOS:
#   1. "Minimize operational overhead for a web API" → App Service
#   2. "Run nightly batch processing of 10K files" → Azure Batch or ACI
#   3. "Real-time event processing from IoT Hub" → Azure Functions
#   4. "Migrate .NET Framework app with zero code changes" → VM (IaaS)
#   5. "20 microservices with service-to-service auth" → AKS
#   6. "Execute code only when a blob is uploaded" → Functions Blob trigger
#   7. "Run CI/CD build agent on demand" → ACI
#   8. "API must respond in <100ms, no cold starts" → Functions Premium
#   9. "Render 50,000 video frames overnight" → Azure Batch + Spot VMs
#  10. "Web app needs deployment slots for zero-downtime releases" → App Service S1+
# =============================================================================
