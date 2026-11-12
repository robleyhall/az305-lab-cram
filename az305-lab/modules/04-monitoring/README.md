# Module 04: Monitoring & Alerting

## AZ-305 Exam Relevance

This module covers the **"Design identity, governance, and monitoring solutions"** domain, which accounts for **25–30 %** of AZ-305 exam questions. Monitoring-specific topics include:

| Topic | What to Know |
|-------|-------------|
| Azure Monitor architecture | Metrics vs Logs vs Activity Log — when each is used |
| Log Analytics workspace design | Single vs multiple workspace strategies; cost, RBAC, residency |
| KQL (Kusto Query Language) | Basic query structure, common operators (`where`, `summarize`, `project`) |
| Alert types | Metric alerts, log alerts, activity-log alerts, smart detection |
| Action groups | Notification mechanisms, receiver types, common alert schema |
| Alert processing rules | Suppress or augment notifications without editing alert rules |
| Application Insights | Workspace-based model, instrumentation key vs connection string |
| Azure Monitor Agent (AMA) | Replaces legacy MMA/OMS; uses Data Collection Rules (DCRs) |
| Workbooks vs Dashboards | Workbooks for deep analysis; dashboards for at-a-glance status |
| Cost management | PerGB2018 pricing, commitment tiers, free tier limits |

## What This Module Creates

| Resource | Name | Purpose |
|----------|------|---------|
| Resource Group | `az305-lab-monitoring-rg` | Container for all monitoring resources |
| Application Insights | `az305-lab-appinsights` | APM — workspace-based (linked to Log Analytics) |
| Action Group | `az305-lab-alerts-ag` | Email notification target for all alert rules |
| Metric Alert | `az305-lab-cpu-alert` | Fires when VM CPU > 80 % in foundation RG |
| Activity Log Alert | `az305-lab-delete-alert` | Fires on admin operations in foundation RG |
| Scheduled Query Rule | `az305-lab-error-query` | KQL-based alert for Error-level log events |
| Diagnostic Setting | `az305-lab-sub-activity-diag` | Routes subscription Activity Log to Log Analytics |
| Portal Dashboard | `az305-lab-monitoring-dashboard` | Shared dashboard with overview tiles |

## Prerequisites

- Terraform ≥ 1.5.0
- AzureRM provider ~> 4.0
- Azure CLI authenticated (`az login`)
- **Module 00 (Foundation)** deployed — provides resource group and Log Analytics workspace

## Usage

```bash
# 1. Get foundation outputs
cd ../00-foundation
terraform output

# 2. Configure this module
cd ../04-monitoring
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with values from step 1

# 3. Deploy
terraform init
terraform plan
terraform apply

# 4. Verify in the Azure Portal
#    - Navigate to Monitor → Alerts to see alert rules
#    - Navigate to Application Insights → az305-lab-appinsights
#    - Navigate to Dashboards → AZ-305 Monitoring Dashboard

# 5. Tear down when done
terraform destroy
```

## Inputs

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `location` | string | `"eastus"` | Azure region |
| `prefix` | string | `"az305-lab"` | Naming prefix for all resources |
| `foundation_resource_group_name` | string | — | Name of the foundation RG (Module 00 output) |
| `log_analytics_workspace_id` | string | — | Resource ID of the Log Analytics workspace (Module 00 output) |
| `alert_email` | string | `"admin@example.com"` | Email address for alert notifications |
| `tags` | map(string) | Lab/CostCenter/ManagedBy | Tags merged onto all resources |

## Outputs

| Output | Description |
|--------|-------------|
| `resource_group_name` | Name of the monitoring resource group |
| `application_insights_id` | Resource ID of Application Insights |
| `application_insights_instrumentation_key` | Instrumentation key (sensitive) |
| `application_insights_connection_string` | Connection string (sensitive, preferred) |
| `action_group_id` | Resource ID of the shared action group |

## Dependencies

```
Module 00 (Foundation)
  └── log_analytics_workspace_id
  └── foundation_resource_group_name
          │
          ▼
    Module 04 (Monitoring)
```

## Estimated Cost

| Component | Estimate |
|-----------|----------|
| Application Insights | First 5 GB/month free; ~$2.30/GB after |
| Log Analytics ingestion | First 5 GB/month free; ~$2.30/GB after |
| Metric alert evaluations | First 1 000/month free |
| Activity Log routing | Free |
| Dashboard | Free |
| **Total (lab usage)** | **~$0–2/day** |

> **Tip:** Destroy resources when not studying to avoid charges. The `terraform destroy` command removes everything cleanly.
