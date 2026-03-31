# =============================================================================
# AZ-305 Lab — Module 04: Monitoring & Alerting
# =============================================================================
# Builds a complete Azure Monitor observability stack: Application Insights,
# metric alerts, activity-log alerts, log-based (KQL) alerts, diagnostic
# settings, and a portal dashboard.  The foundation module (00) provides the
# Log Analytics workspace — this module extends it with alerting and
# visualisation.
#
# AZ-305 Exam Relevance:
#   - Monitoring is part of the "Design identity, governance, and monitoring
#     solutions" domain (25-30 % of exam questions).
#   - Key topics: Azure Monitor architecture (metrics vs logs vs activity log),
#     Log Analytics workspace design, KQL basics, alert severity and
#     processing rules, Application Insights, workbooks vs dashboards.
#
# Azure Monitor Architecture (exam concept):
#   ┌──────────────────────────────────────────────────────────────┐
#   │                      Azure Monitor                           │
#   │  ┌──────────┐   ┌──────────────┐   ┌───────────────────┐    │
#   │  │  Metrics  │   │     Logs     │   │   Activity Log    │    │
#   │  │ (numeric, │   │ (structured, │   │ (subscription-    │    │
#   │  │  1-min    │   │  KQL query-  │   │  level control-   │    │
#   │  │  grains)  │   │  able, Log   │   │  plane events)    │    │
#   │  │           │   │  Analytics)  │   │                   │    │
#   │  └─────┬─────┘   └──────┬───────┘   └────────┬──────────┘   │
#   │        │                │                     │              │
#   │        ▼                ▼                     ▼              │
#   │  ┌──────────────────────────────────────────────────┐       │
#   │  │         Alerts  →  Action Groups  →  Notify      │       │
#   │  └──────────────────────────────────────────────────┘       │
#   └──────────────────────────────────────────────────────────────┘
#
# Cost Estimate: ~$2/day
#   - Application Insights: first 5 GB/month free, then ~$2.30/GB
#   - Log Analytics:        first 5 GB/month free (PerGB2018 pricing)
#   - Alerts:               first 1 000 metric alert evaluations/month free
#   - Dashboard:            free
# =============================================================================

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  features {}
}

# =============================================================================
# LOCALS
# =============================================================================

locals {
  common_tags = merge(var.tags, {
    Module  = "04-monitoring"
    Purpose = "Azure Monitor observability stack for AZ-305 lab"
  })
}

# =============================================================================
# DATA SOURCES
# =============================================================================
# Reference foundation-module resources without hard-coding names.
# =============================================================================

data "azurerm_resource_group" "foundation" {
  name = var.foundation_resource_group_name
}

data "azurerm_subscription" "current" {}

# =============================================================================
# RESOURCE GROUP
# =============================================================================
# Each module gets its own resource group so it can be deployed / destroyed
# independently.  Resource-group names need not be globally unique, so no
# random suffix is required.
# =============================================================================

resource "azurerm_resource_group" "monitoring" {
  name     = "${var.prefix}-monitoring-rg"
  location = var.location
  tags     = local.common_tags

  lifecycle {
    # Non-semantic: Azure auto-adds rg-class tag for internal classification. Not a config choice.
    ignore_changes = [tags["rg-class"]]
  }
}

# =============================================================================
# APPLICATION INSIGHTS (workspace-based)
# =============================================================================
# AZ-305 Exam Note — Application Insights vs Log Analytics:
#   • Application Insights  = application performance monitoring (APM).
#     Captures requests, dependencies, exceptions, page views, custom events.
#     Best for: web apps, APIs, microservices instrumented with the App
#     Insights SDK or auto-instrumentation.
#   • Log Analytics          = general-purpose log store.
#     Ingests platform logs, diagnostic logs, custom logs via DCRs.
#     Best for: infrastructure monitoring, cross-resource correlation, Sentinel.
#
#   Modern best practice: always use "workspace-based" Application Insights
#   (set workspace_id).  Classic (standalone) mode is deprecated and will be
#   retired.  Workspace-based mode stores all telemetry in the underlying Log
#   Analytics workspace, enabling unified KQL queries across app and infra
#   data, and a single retention / cost policy.
#
# AZ-305 Exam Note — Azure Monitor Agent (AMA) vs legacy agents:
#   • Legacy agents (MMA / OMS, Dependency Agent) are deprecated.
#   • Azure Monitor Agent (AMA) is the replacement — uses Data Collection
#     Rules (DCRs) to define what data to collect and where to send it.
#   • DCRs decouple "what to collect" from "where to send", enabling
#     multi-homing (same data → multiple workspaces) and filtering at source.
#   • AMA + DCR is the only supported model for new deployments.
# =============================================================================

resource "azurerm_application_insights" "main" {
  name                = "${var.prefix}-appinsights"
  resource_group_name = azurerm_resource_group.monitoring.name
  location            = azurerm_resource_group.monitoring.location
  workspace_id        = var.log_analytics_workspace_id
  application_type    = "web"
  tags                = local.common_tags
}

# =============================================================================
# ACTION GROUP
# =============================================================================
# AZ-305 Exam Note — Action Groups:
#   Action groups are the "who to notify and how" component of Azure Monitor
#   alerts.  A single action group can contain multiple receiver types:
#     • Email / SMS / Voice / Push notification
#     • Azure Function, Logic App, Webhook, ITSM connector
#     • Automation Runbook, Event Hub
#   Alert rules reference one or more action groups; action groups are reusable
#   across many alert rules.
#
#   Alert Processing Rules (formerly "action rules") sit between an alert and
#   its action groups.  They can suppress notifications (e.g., during a
#   maintenance window) or add additional action groups without editing the
#   original alert rule.  Exam tip: know the difference between "alert rules"
#   and "alert processing rules".
# =============================================================================

resource "azurerm_monitor_action_group" "alerts" {
  name                = "${var.prefix}-alerts-ag"
  resource_group_name = azurerm_resource_group.monitoring.name
  short_name          = "az305labalrt"
  tags                = local.common_tags

  email_receiver {
    name                    = "admin-email"
    email_address           = var.alert_email
    use_common_alert_schema = true
  }
}

# =============================================================================
# METRIC ALERT — VM CPU
# =============================================================================
# AZ-305 Exam Note — Alert severity levels:
#   Sev 0 = Critical   (e.g., production service down)
#   Sev 1 = Error      (e.g., high error rate)
#   Sev 2 = Warning    (e.g., CPU > 80 %, approaching limits)
#   Sev 3 = Informational
#   Sev 4 = Verbose
#   Exam tip: severity is metadata only — it does NOT change alert behaviour.
#   Use it to drive routing logic in action groups or ITSM integrations.
#
# Multi-resource metric alerts:
#   When the scope is a resource group (not an individual resource), Azure
#   Monitor evaluates the metric for every resource of `target_resource_type`
#   in that group.  This avoids creating one alert rule per VM.
#   Required fields: target_resource_type, target_resource_location.
#
# This alert fires when ANY VM deployed by other lab modules into the
# foundation resource group exceeds 80 % average CPU over 5 minutes.
# =============================================================================

resource "azurerm_monitor_metric_alert" "cpu" {
  name                     = "${var.prefix}-cpu-alert"
  resource_group_name      = azurerm_resource_group.monitoring.name
  description              = "Fires when VMs in the foundation RG exceed 80% average CPU for 5 min"
  severity                 = 2
  frequency                = "PT5M"
  window_size              = "PT5M"
  scopes                   = [data.azurerm_resource_group.foundation.id]
  target_resource_type     = "Microsoft.Compute/virtualMachines"
  target_resource_location = var.location

  criteria {
    metric_namespace = "Microsoft.Compute/virtualMachines"
    metric_name      = "Percentage CPU"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 80
  }

  action {
    action_group_id = azurerm_monitor_action_group.alerts.id
  }

  tags = local.common_tags
}

# =============================================================================
# ACTIVITY LOG ALERT — RESOURCE DELETION
# =============================================================================
# AZ-305 Exam Note — Activity Log:
#   The Activity Log records control-plane (ARM) operations: who did what, when,
#   and from where.  Categories include:
#     Administrative — CRUD on resources (create, update, delete)
#     Security       — Microsoft Defender for Cloud alerts
#     Service Health — outage and maintenance notifications
#     Recommendation — Azure Advisor
#     Policy         — Azure Policy evaluation events
#     Autoscale      — scale-in / scale-out events
#
#   Activity Log alerts differ from metric/log alerts: they evaluate ARM events,
#   NOT telemetry data.  They are always subscription-scoped.
#
# This alert triggers on any administrative activity (create/update/delete)
# within the foundation resource group.  In production you would narrow the
# criteria with a specific operation_name such as
# "Microsoft.Compute/virtualMachines/delete" to reduce noise.
# =============================================================================

resource "azurerm_monitor_activity_log_alert" "resource_delete" {
  name                = "${var.prefix}-delete-alert"
  resource_group_name = azurerm_resource_group.monitoring.name
  location            = "global"
  description         = "Alert on administrative operations in the foundation resource group"
  scopes              = [data.azurerm_subscription.current.id]

  criteria {
    category       = "Administrative"
    resource_group = var.foundation_resource_group_name
  }

  action {
    action_group_id = azurerm_monitor_action_group.alerts.id
  }

  tags = local.common_tags
}

# =============================================================================
# SCHEDULED QUERY RULE (LOG ALERT) — ERROR EVENTS
# =============================================================================
# AZ-305 Exam Note — Log alerts (KQL-based):
#   Log alerts run a KQL query against a Log Analytics workspace on a schedule.
#   If the query returns results that breach a threshold, an alert fires.
#
#   Key parameters:
#     evaluation_frequency — how often the query runs (e.g., PT5M = every 5 min)
#     window_duration      — the time range the query looks back over
#     time_aggregation_method — Count, Average, Min, Max, Total
#     failing_periods      — how many consecutive evaluation periods must breach
#                            before firing (reduces flapping)
#
# KQL basics for the exam:
#   Event | where EventLevelName == "Error"                       -- filter
#   | summarize count() by bin(TimeGenerated, 5m), Computer      -- aggregate
#   | order by TimeGenerated desc                                 -- sort
#   | project TimeGenerated, Computer, count_                     -- select cols
#
# Common exam KQL scenarios:
#   • Heartbeat | summarize LastHeartbeat = max(TimeGenerated) by Computer
#     | where LastHeartbeat < ago(5m)                — detect offline VMs
#   • AzureActivity | where OperationNameValue endswith "delete"
#     | summarize count() by Caller                  — audit deletions
#   • Perf | where ObjectName == "Processor" and CounterName == "% Processor Time"
#     | summarize AvgCPU = avg(CounterValue) by Computer, bin(TimeGenerated, 5m)
# =============================================================================

resource "azurerm_monitor_scheduled_query_rules_alert_v2" "error_query" {
  name                 = "${var.prefix}-error-query"
  resource_group_name  = azurerm_resource_group.monitoring.name
  location             = azurerm_resource_group.monitoring.location
  description          = "Fires when Error-level events appear in Log Analytics"
  severity             = 2
  evaluation_frequency = "PT5M"
  window_duration      = "PT5M"
  scopes               = [var.log_analytics_workspace_id]

  criteria {
    query = <<-KQL
      Event
      | where EventLevelName == "Error"
      | project TimeGenerated, Source, EventLog, RenderedDescription
    KQL

    time_aggregation_method = "Count"
    threshold               = 0
    operator                = "GreaterThan"

    failing_periods {
      minimum_failing_periods_to_trigger_alert = 1
      number_of_evaluation_periods             = 1
    }
  }

  action {
    action_groups = [azurerm_monitor_action_group.alerts.id]
  }

  auto_mitigation_enabled = true
  tags                    = local.common_tags
}

# =============================================================================
# DIAGNOSTIC SETTING — SUBSCRIPTION ACTIVITY LOG → LOG ANALYTICS
# =============================================================================
# AZ-305 Exam Note — Diagnostic Settings:
#   Every Azure resource can emit platform logs and metrics via diagnostic
#   settings.  Destinations include:
#     • Log Analytics workspace (for KQL queries)
#     • Storage Account       (for long-term archival / compliance)
#     • Event Hub             (for streaming to external SIEM)
#   You can send the same data to multiple destinations simultaneously.
#
#   The subscription itself is a "resource" that emits the Activity Log.
#   By routing it to Log Analytics you can:
#     1. Query activity events with KQL (more powerful than the portal UI)
#     2. Correlate control-plane events with resource-level telemetry
#     3. Set up log-based alerts on activity events (as shown above)
#     4. Retain activity data beyond the default 90 days
#
# Cost note:
#   Activity Log ingestion into Log Analytics is free for the categories
#   shown below (Administrative, Security, etc.).  This does NOT count
#   against the workspace's paid ingestion quota.
# =============================================================================

resource "azurerm_monitor_diagnostic_setting" "subscription_activity" {
  name                       = "${var.prefix}-sub-activity-diag"
  target_resource_id         = data.azurerm_subscription.current.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "Administrative"
  }

  enabled_log {
    category = "Security"
  }

  enabled_log {
    category = "Alert"
  }

  enabled_log {
    category = "Policy"
  }

  enabled_log {
    category = "Autoscale"
  }

  enabled_log {
    category = "Recommendation"
  }
}

# =============================================================================
# AZURE PORTAL DASHBOARD
# =============================================================================
# AZ-305 Exam Note — Workbooks vs Dashboards:
#   • Azure Workbooks   — rich, interactive reports built on KQL queries.
#     Support parameters, conditional visibility, and multiple visualisation
#     types.  Preferred for deep analysis and troubleshooting.
#   • Azure Dashboards  — lightweight portal pinboards.  Good for at-a-glance
#     status and sharing with stakeholders.  Limited interactivity.
#
#   Exam tip: Workbooks are the recommended tool for most monitoring
#   scenarios.  Dashboards are best for "big screen" / NOC displays.
#
# Log Analytics workspace design (exam concept):
#   Single workspace — simpler management, cross-resource KQL queries, lower
#     cost (single ingestion pool).  Recommended for most organisations.
#   Multiple workspaces — needed when:
#     • Data residency requires different regions
#     • Strict RBAC separation (e.g., security team has dedicated workspace)
#     • Separate billing entities
#   This lab uses a single workspace (created in Module 00) for simplicity,
#   which matches the most common design recommendation.
#
# Cost implications of log ingestion (PerGB2018 pricing):
#   • Free tier: 5 GB/month included
#   • Pay-as-you-go: ~$2.30/GB after free tier
#   • Commitment tiers: 100 GB/day+ for volume discounts (25-50 % savings)
#   • Retention: 31 days interactive free; up to 730 days (12 years archive)
#   • Data Collection Rules can filter/transform at source to reduce volume
# =============================================================================

resource "azurerm_portal_dashboard" "monitoring" {
  name                = "${var.prefix}-monitoring-dashboard"
  resource_group_name = azurerm_resource_group.monitoring.name
  location            = azurerm_resource_group.monitoring.location

  tags = merge(local.common_tags, {
    "hidden-title" = "AZ-305 Monitoring Dashboard"
  })

  dashboard_properties = jsonencode({
    lenses = {
      "0" = {
        order = 0
        parts = {
          # --- Tile 0: Overview Markdown ---
          "0" = {
            position = { x = 0, y = 0, colSpan = 6, rowSpan = 4 }
            metadata = {
              type   = "Extension/HubsExtension/PartType/MarkdownPart"
              inputs = []
              settings = {
                content = {
                  settings = {
                    content  = <<-MD
## AZ-305 Monitoring Dashboard

**Resources monitored:**
- Log Analytics workspace → KQL queries, log alerts
- Application Insights → APM telemetry
- VM CPU metrics → threshold alerts
- Activity Log → control-plane audit

**Key concepts for the exam:**
- Metrics = numeric time-series (near real-time, 93-day retention)
- Logs = structured text in Log Analytics (queryable via KQL)
- Activity Log = ARM control-plane events (90-day default)
MD
                    title    = "Monitoring Overview"
                    subtitle = "AZ-305 Certification Lab"
                  }
                }
              }
            }
          }

          # --- Tile 1: CPU Metrics Markdown ---
          "1" = {
            position = { x = 6, y = 0, colSpan = 6, rowSpan = 4 }
            metadata = {
              type   = "Extension/HubsExtension/PartType/MarkdownPart"
              inputs = []
              settings = {
                content = {
                  settings = {
                    content  = <<-MD
## CPU Metrics Alert

**Alert:** ${var.prefix}-cpu-alert
- Scope: Foundation resource group (all VMs)
- Threshold: Average CPU > 80% for 5 minutes
- Severity: 2 (Warning)

**Exam tip:** Multi-resource metric alerts scope to a
resource group and evaluate ALL resources of the target type.
No need for one alert per VM.
MD
                    title    = "CPU Metrics"
                    subtitle = "Metric Alert Configuration"
                  }
                }
              }
            }
          }

          # --- Tile 2: Activity Log Markdown ---
          "2" = {
            position = { x = 0, y = 4, colSpan = 6, rowSpan = 4 }
            metadata = {
              type   = "Extension/HubsExtension/PartType/MarkdownPart"
              inputs = []
              settings = {
                content = {
                  settings = {
                    content  = <<-MD
## Activity Log Monitoring

**Alert:** ${var.prefix}-delete-alert
- Watches administrative operations in foundation RG
- Categories: Administrative, Security, Policy, Autoscale

**Exam tip:** Activity Log data is free to route to
Log Analytics.  Default retention is 90 days in the portal,
but stored in Log Analytics it follows workspace retention
(31 days free, up to 730 days paid).
MD
                    title    = "Activity Log"
                    subtitle = "Control-Plane Audit"
                  }
                }
              }
            }
          }

          # --- Tile 3: Log Analytics Markdown ---
          "3" = {
            position = { x = 6, y = 4, colSpan = 6, rowSpan = 4 }
            metadata = {
              type   = "Extension/HubsExtension/PartType/MarkdownPart"
              inputs = []
              settings = {
                content = {
                  settings = {
                    content  = <<-MD
## Log Analytics Workspace

**Workspace:** provided by Module 00 (foundation)
**Pricing tier:** PerGB2018 (pay-as-you-go)

**Linked resources:**
- Application Insights (workspace-based)
- Subscription activity log (diagnostic setting)
- Error log alert (scheduled KQL query)

**Exam tip:** Single-workspace design is recommended
unless data residency, RBAC, or billing require separation.
MD
                    title    = "Log Analytics"
                    subtitle = "Workspace Overview"
                  }
                }
              }
            }
          }
        }
      }
    }

    metadata = {
      model = {
        timeRange = {
          value = {
            relative = {
              duration = 24
              timeUnit = 1
            }
          }
          type = "MsPortalFx.Composition.Configuration.ValueTypes.TimeRange"
        }
        filterLocale = {
          value = "en-us"
        }
      }
    }
  })
}
