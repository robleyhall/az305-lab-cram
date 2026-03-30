# =============================================================================
# AZ-305 Lab — Module 10: Application Architecture
# =============================================================================
# This module deploys messaging, eventing, API management, and caching
# services that are heavily tested on the AZ-305 exam. Understanding when
# to choose each service is CRITICAL for exam success.
#
# Resources created:
#   • Event Grid Topic + Subscription     — reactive event routing
#   • Event Hubs Namespace + Event Hub     — high-throughput streaming
#   • Service Bus Namespace + Queue/Topic  — enterprise messaging
#   • API Management (Consumption tier)    — API gateway
#   • Redis Cache (Basic)                  — caching pattern
#   • Diagnostic settings                  — observability
# =============================================================================

terraform {
  required_providers {
    azurerm = { source = "hashicorp/azurerm", version = "~> 4.0" }
  }
}

provider "azurerm" {
  features {}
}

# -----------------------------------------------------------------------------
# Random suffix for globally unique names
# -----------------------------------------------------------------------------

resource "random_string" "suffix" {
  length  = 6
  upper   = false
  special = false
}

# -----------------------------------------------------------------------------
# Common tags — merged with user-supplied tags
# -----------------------------------------------------------------------------

locals {
  common_tags = merge(var.tags, {
    Module  = "10-app-architecture"
    Purpose = "Messaging, eventing, API management, and caching"
  })
}

# =============================================================================
# RESOURCE GROUP
# =============================================================================

resource "azurerm_resource_group" "apparch" {
  name     = "${var.prefix}-apparch-rg"
  location = var.location
  tags     = local.common_tags
}

# =============================================================================
# EVENT GRID
# =============================================================================
# AZ-305 EXAM TOPIC: Event Grid — Reactive Event Routing
# ---------------------------------------------------------------------------
# Event Grid is a fully managed event routing service using a pub/sub model.
#
#   Key characteristics:
#     - Push-based delivery (HTTP webhooks, queues, Event Hubs, etc.)
#     - At-least-once delivery guarantee
#     - Near real-time event delivery (sub-second latency)
#     - Built-in support for Azure resource events (system topics)
#     - Custom topics for application events
#     - Event filtering and dead-lettering
#
#   When to use:
#     - React to Azure resource state changes (blob created, VM started)
#     - Serverless event-driven architectures
#     - Fan-out scenarios: one event → many subscribers
#     - IoT device telemetry routing
#
#   Comparison with other services:
#     Event Grid vs Event Hubs:
#       Event Grid = discrete events, push model, reactive
#       Event Hubs = event streams, pull model (consumer groups), analytics
#     Event Grid vs Service Bus:
#       Event Grid = lightweight notifications, no ordering guarantee
#       Service Bus = heavyweight transactions, ordered, exactly-once
# ---------------------------------------------------------------------------

resource "azurerm_eventgrid_topic" "main" {
  name                = "${var.prefix}-egt"
  location            = azurerm_resource_group.apparch.location
  resource_group_name = azurerm_resource_group.apparch.name
  input_schema        = "EventGridSchema"
  tags                = local.common_tags
}

# Event Grid subscription — demonstrates event routing to a webhook endpoint.
# In production, replace the placeholder URL with an Azure Function, Logic App,
# or any HTTPS endpoint that can handle the validation handshake.
resource "azurerm_eventgrid_event_subscription" "main" {
  name  = "${var.prefix}-egt-sub"
  scope = azurerm_eventgrid_topic.main.id

  webhook_endpoint {
    url = "https://example.com/api/events"
  }

  retry_policy {
    max_delivery_attempts = 30
    event_time_to_live    = 1440
  }
}

# =============================================================================
# EVENT HUBS
# =============================================================================
# AZ-305 EXAM TOPIC: Event Hubs — High-Throughput Event Streaming
# ---------------------------------------------------------------------------
# Event Hubs is a big-data streaming platform and event ingestion service.
#
#   Key characteristics:
#     - Millions of events per second (throughput units scale capacity)
#     - Kafka-compatible (use existing Kafka clients with no code changes)
#     - Partitioned consumer model (parallel processing)
#     - Event replay via consumer groups and offsets
#     - Capture feature: auto-archive to Blob/Data Lake in Avro format
#
#   When to use:
#     - Telemetry and IoT data ingestion at massive scale
#     - Stream processing with Azure Stream Analytics or Apache Spark
#     - Real-time analytics pipelines
#     - Application logging / distributed tracing aggregation
#
#   SKU comparison:
#     Basic:    1 consumer group, 1-day retention, no Capture
#     Standard: 20 consumer groups, 7-day retention, Capture available
#     Premium:  Dynamic partitions, zone redundancy, 90-day retention
#     Dedicated: single-tenant cluster, highest throughput
#
#   Partitions:
#     - Each partition is an ordered sequence of events
#     - More partitions = more parallel consumers
#     - Partition count CANNOT be changed after creation (plan carefully!)
#     - Events are distributed via partition key (or round-robin if none)
# ---------------------------------------------------------------------------

resource "azurerm_eventhub_namespace" "main" {
  name                = "${var.prefix}-ehn-${random_string.suffix.result}"
  location            = azurerm_resource_group.apparch.location
  resource_group_name = azurerm_resource_group.apparch.name
  sku                 = "Standard"
  capacity            = 1
  tags                = local.common_tags
}

resource "azurerm_eventhub" "main" {
  name              = "${var.prefix}-eventhub"
  namespace_id      = azurerm_eventhub_namespace.main.id
  partition_count   = 2
  message_retention = 1
}

resource "azurerm_eventhub_consumer_group" "main" {
  name                = "${var.prefix}-consumer"
  namespace_name      = azurerm_eventhub_namespace.main.name
  eventhub_name       = azurerm_eventhub.main.name
  resource_group_name = azurerm_resource_group.apparch.name
  user_metadata       = "AZ-305 lab consumer group for demonstrating parallel event processing"
}

# =============================================================================
# SERVICE BUS
# =============================================================================
# AZ-305 EXAM TOPIC: Service Bus — Enterprise Messaging (CRITICAL)
# ---------------------------------------------------------------------------
# Service Bus is a fully managed enterprise message broker with queues and
# publish/subscribe topics. It is the go-to choice for business-critical
# messaging that requires ordering, transactions, or deduplication.
#
#   Key characteristics:
#     - Ordered delivery (FIFO) with sessions
#     - Exactly-once processing (via peek-lock + complete)
#     - Dead-letter queue (DLQ) for poison messages
#     - Duplicate detection (based on message ID, configurable window)
#     - Scheduled delivery and deferral
#     - Transactions across multiple queues/topics
#     - Auto-forwarding between entities
#
#   Queues vs Topics:
#     Queue: point-to-point, one sender → one receiver
#     Topic: publish/subscribe, one sender → many subscriptions (with filters)
#
#   When to use:
#     - Order processing / financial transactions requiring ordering
#     - Business workflows with guaranteed delivery
#     - Decouple microservices with reliable async messaging
#     - When you need sessions (grouped message processing)
#     - When you need dead-letter handling for failed messages
#
#   Service Bus vs Storage Queue:
#     Service Bus: rich features, ordered, exactly-once, <80GB, higher cost
#     Storage Queue: simple, large capacity (>80GB), at-least-once, lower cost
#     Exam tip: "simple decoupling with large volumes" → Storage Queue
#               "business transactions with ordering"  → Service Bus
#
# ---------------------------------------------------------------------------
# COMPLETE MESSAGING SERVICE COMPARISON (AZ-305 CRITICAL):
# ---------------------------------------------------------------------------
#
#   Service         | Model       | Delivery        | Use Case
#   ────────────────|─────────────|─────────────────|─────────────────────────
#   Event Grid      | Pub/Sub     | At-least-once   | React to resource events
#   Event Hubs      | Streaming   | At-least-once   | Telemetry, millions/sec
#   Service Bus     | Queue/Topic | Exactly-once    | Business transactions
#   Storage Queue   | Queue       | At-least-once   | Simple async, >80GB
#
# ---------------------------------------------------------------------------

resource "azurerm_servicebus_namespace" "main" {
  name                = "${var.prefix}-sbn-${random_string.suffix.result}"
  location            = azurerm_resource_group.apparch.location
  resource_group_name = azurerm_resource_group.apparch.name
  sku                 = "Standard"
  tags                = local.common_tags
}

# Service Bus Queue — point-to-point messaging with dead-lettering enabled.
# Dead-lettering moves messages that cannot be processed (expired, max delivery
# exceeded, or filter evaluation fails) to a special sub-queue for inspection.
resource "azurerm_servicebus_queue" "main" {
  name                                 = "${var.prefix}-queue"
  namespace_id                         = azurerm_servicebus_namespace.main.id
  max_size_in_megabytes                = 1024
  dead_lettering_on_message_expiration = true
}

# Service Bus Topic — pub/sub messaging. Multiple subscriptions can receive
# copies of each message, optionally filtered by SQL-like rules.
resource "azurerm_servicebus_topic" "main" {
  name                = "${var.prefix}-topic"
  namespace_id        = azurerm_servicebus_namespace.main.id
  max_size_in_megabytes = 1024
}

# Service Bus Subscription — attached to the topic. max_delivery_count controls
# how many times a message is retried before being dead-lettered.
resource "azurerm_servicebus_subscription" "main" {
  name                = "${var.prefix}-sub"
  topic_id            = azurerm_servicebus_topic.main.id
  max_delivery_count  = 10
}

# =============================================================================
# API MANAGEMENT
# =============================================================================
# AZ-305 EXAM TOPIC: API Management — API Gateway Pattern
# ---------------------------------------------------------------------------
# Azure API Management (APIM) provides a unified API gateway for backend
# services. It handles authentication, rate limiting, transformation,
# caching, monitoring, and developer engagement.
#
#   APIM Tiers (exam frequently tests tier selection):
#     Consumption: serverless, pay-per-call, no infrastructure to manage,
#                  auto-scales, 99.95% SLA, limited features
#     Developer:   non-production only, no SLA, self-hosted gateway option,
#                  built-in developer portal
#     Basic:       production entry-level, no VNet integration, 99.95% SLA
#     Standard:    built-in cache, 99.95% SLA, higher scale limits
#     Premium:     multi-region deployment, VNet integration (internal &
#                  external), availability zones, self-hosted gateway,
#                  99.99% SLA, highest scale
#
#   Key APIM concepts:
#     APIs:            Backend services exposed through APIM
#     Products:        Bundles of APIs offered to developers (with terms)
#     Subscriptions:   Keys that grant access to products/APIs
#     Policies:        XML-based rules applied at inbound/backend/outbound
#                      stages (rate-limit, transform, cache, JWT validate)
#     Developer Portal: Auto-generated documentation site for API consumers
#     Named Values:    Key-value pairs for policy configuration (can ref KV)
#     Backends:        Named backend service configurations
#
#   Common policies (exam relevant):
#     - rate-limit / rate-limit-by-key: throttle request rate
#     - quota / quota-by-key: limit total calls per period
#     - validate-jwt: authenticate with Azure AD / OAuth
#     - set-header / set-body: transform request/response
#     - cache-lookup / cache-store: response caching
#     - rewrite-uri: URL path rewriting
#     - cors: cross-origin resource sharing
#     - ip-filter: allow/deny by IP address
#
#   When to use APIM:
#     - Expose multiple backend services under a single endpoint
#     - Apply cross-cutting concerns (auth, rate limiting) without code changes
#     - Version and revision management for APIs
#     - Monetize APIs via subscription keys and products
#     - Internal API governance across teams
# ---------------------------------------------------------------------------

resource "azurerm_api_management" "main" {
  name                = "${var.prefix}-apim-${random_string.suffix.result}"
  location            = azurerm_resource_group.apparch.location
  resource_group_name = azurerm_resource_group.apparch.name
  publisher_name      = var.apim_publisher_name
  publisher_email     = var.apim_publisher_email
  sku_name            = "Consumption_0"
  tags                = local.common_tags
}

# =============================================================================
# REDIS CACHE
# =============================================================================
# AZ-305 EXAM TOPIC: Caching Patterns
# ---------------------------------------------------------------------------
# Azure Cache for Redis is a fully managed in-memory data store used to
# accelerate application performance by caching frequently accessed data.
#
#   Caching patterns:
#     Cache-Aside (Lazy Loading):
#       1. App checks cache for data
#       2. On miss: read from database, write to cache, return
#       3. On hit: return cached data directly
#       Best for: read-heavy workloads, data that doesn't change often
#
#     Write-Through:
#       1. App writes to cache AND database simultaneously
#       Best for: data consistency is critical
#
#     Write-Behind (Write-Back):
#       1. App writes to cache; cache async-writes to database
#       Best for: write-heavy workloads, eventual consistency OK
#
#   Azure Cache for Redis tiers:
#     Basic:    single node, no SLA, dev/test only (this lab)
#     Standard: replicated (primary/secondary), 99.9% SLA
#     Premium:  clustering, persistence, VNet, zone redundancy, 99.9% SLA
#     Enterprise:  Redis Enterprise modules (RediSearch, RedisBloom, etc.)
#     Enterprise Flash: NVMe storage for large datasets at lower cost
#
#   When to cache:
#     - Read-heavy workloads (high read-to-write ratio)
#     - Latency-sensitive operations (sub-millisecond access)
#     - Expensive database queries / computed results
#     - Session state in web applications
#     - Leaderboards, counters, rate limiting
#     - Pub/sub messaging between application tiers
#
#   Best practices:
#     - Set appropriate TTL (time-to-live) for cache entries
#     - Handle cache misses gracefully (thundering herd protection)
#     - Use TLS 1.2+ for all connections (enforced below)
#     - Monitor cache hit/miss ratio to right-size the instance
# ---------------------------------------------------------------------------

resource "azurerm_redis_cache" "main" {
  name                          = "${var.prefix}-redis-${random_string.suffix.result}"
  location                      = azurerm_resource_group.apparch.location
  resource_group_name           = azurerm_resource_group.apparch.name
  capacity                      = 0
  family                        = "C"
  sku_name                      = "Basic"
  minimum_tls_version           = "1.2"
  non_ssl_port_enabled          = false
  tags                          = local.common_tags
}

# =============================================================================
# DIAGNOSTIC SETTINGS
# =============================================================================
# Send logs and metrics from Event Hubs, Service Bus, and APIM to the shared
# Log Analytics workspace created in Module 00 (Foundation). Retention is
# configured on the workspace itself (30 days), not on each diagnostic setting.
# ---------------------------------------------------------------------------

resource "azurerm_monitor_diagnostic_setting" "eventhubs" {
  name                       = "${var.prefix}-ehn-diag"
  target_resource_id         = azurerm_eventhub_namespace.main.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "ArchiveLogs"
  }

  enabled_log {
    category = "OperationalLogs"
  }

  enabled_metric {
    category = "AllMetrics"
  }
}

resource "azurerm_monitor_diagnostic_setting" "servicebus" {
  name                       = "${var.prefix}-sbn-diag"
  target_resource_id         = azurerm_servicebus_namespace.main.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "OperationalLogs"
  }

  enabled_metric {
    category = "AllMetrics"
  }
}

resource "azurerm_monitor_diagnostic_setting" "apim" {
  name                       = "${var.prefix}-apim-diag"
  target_resource_id         = azurerm_api_management.main.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "GatewayLogs"
  }

  enabled_metric {
    category = "AllMetrics"
  }
}

# =============================================================================
# ADDITIONAL EXAM TOPICS (not deployed — mention-only)
# =============================================================================
# AZ-305 EXAM TOPIC: Azure App Configuration
# ---------------------------------------------------------------------------
# Azure App Configuration is a managed service for centralizing application
# settings and feature flags.
#
#   Key features:
#     - Centralized configuration store (key-value pairs with labels)
#     - Feature flag management (gradual rollout, A/B testing)
#     - Key Vault references (secrets stored in KV, referenced from App Config)
#     - Configuration snapshots for point-in-time rollback
#     - Change notifications via Event Grid integration
#
#   When to use:
#     - Microservices needing shared configuration
#     - Feature flag management across environments
#     - Separate configuration from code (Twelve-Factor App)
#     - Dynamic configuration updates without redeployment
# ---------------------------------------------------------------------------

# =============================================================================
# AZ-305 EXAM TOPIC: Real-Time Communication Services
# ---------------------------------------------------------------------------
# Azure SignalR Service:
#   - Managed real-time messaging (WebSocket, Server-Sent Events, Long Polling)
#   - Integrates with Azure Functions (serverless real-time)
#   - Use for: live dashboards, chat, notifications, collaborative editing
#
# Azure Web PubSub:
#   - WebSocket-based pub/sub service
#   - Native WebSocket support (no SignalR client SDK required)
#   - Use for: live streaming, IoT command-and-control, gaming
#
# When to choose:
#   SignalR: .NET / JS apps, need auto-transport negotiation, hub model
#   Web PubSub: pure WebSocket, custom protocols, broader language support
# ---------------------------------------------------------------------------
