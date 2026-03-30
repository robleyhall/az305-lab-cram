# Module 10 — Application Architecture

> **AZ-305 Exam Domain:** Design Infrastructure Solutions — **30–35% of exam weight**

## What This Module Creates

| Resource | Name Pattern | Purpose |
|---|---|---|
| Resource Group | `az305-lab-apparch-rg` | Container for all module resources |
| Event Grid Topic | `az305-lab-egt` | Reactive event routing (pub/sub) |
| Event Grid Subscription | `az305-lab-egt-sub` | Webhook event delivery |
| Event Hubs Namespace | `az305-lab-ehn-<suffix>` | High-throughput event streaming platform |
| Event Hub | `az305-lab-eventhub` | Streaming endpoint (2 partitions) |
| Event Hub Consumer Group | `az305-lab-consumer` | Parallel event processing |
| Service Bus Namespace | `az305-lab-sbn-<suffix>` | Enterprise message broker |
| Service Bus Queue | `az305-lab-queue` | Point-to-point messaging with dead-lettering |
| Service Bus Topic | `az305-lab-topic` | Publish/subscribe messaging |
| Service Bus Subscription | `az305-lab-sub` | Topic subscriber (max 10 deliveries) |
| API Management | `az305-lab-apim-<suffix>` | API gateway (Consumption tier) |
| Redis Cache | `az305-lab-redis-<suffix>` | In-memory caching (Basic 250MB) |
| Diagnostic Settings | `az305-lab-*-diag` | Logs & metrics → Log Analytics |

## Key Exam Concepts

### Messaging Service Comparison (CRITICAL)

This is one of the most frequently tested topics on AZ-305. You **must** know when to choose each service.

| Service | Model | Delivery | Throughput | Key Feature | Use Case |
|---|---|---|---|---|---|
| **Event Grid** | Pub/Sub | At-least-once | Moderate | Push-based, reactive | Azure resource events, serverless triggers |
| **Event Hubs** | Streaming | At-least-once | Millions/sec | Kafka-compatible, partitions | Telemetry, IoT, analytics pipelines |
| **Service Bus** | Queue/Topic | Exactly-once | Moderate | Sessions, ordering, DLQ | Business transactions, workflows |
| **Storage Queue** | Queue | At-least-once | Moderate | >80GB capacity, cheap | Simple async decoupling |

### Decision Flowchart

```
Need messaging? ──→ Business ordering/transactions? ──→ YES → Service Bus
                                                    └→ NO
                    Simple decoupling, >80GB queue? ──→ YES → Storage Queue
                                                    └→ NO
                    React to Azure events?         ──→ YES → Event Grid
                                                    └→ NO
                    High-throughput streaming?      ──→ YES → Event Hubs
```

### API Management Tiers

| Tier | Monthly Cost | VNet | Multi-Region | SLA | Use Case |
|---|---|---|---|---|---|
| **Consumption** | Pay-per-call | ❌ | ❌ | 99.95% | Serverless APIs, low traffic |
| **Developer** | ~$50 | ❌ | ❌ | No SLA | Dev/test only |
| **Basic** | ~$150 | ❌ | ❌ | 99.95% | Entry-level production |
| **Standard** | ~$700 | ❌ | ❌ | 99.95% | Production with built-in cache |
| **Premium** | ~$2,800+ | ✅ | ✅ | 99.99% | Enterprise, multi-region, AZ |

### Caching Patterns

| Pattern | How It Works | Best For |
|---|---|---|
| **Cache-Aside** | App checks cache → miss → read DB → write cache | Read-heavy, general purpose |
| **Write-Through** | App writes cache + DB simultaneously | Strong consistency needed |
| **Write-Behind** | App writes cache; cache async-writes DB | Write-heavy, eventual consistency OK |

### Additional Architecture Patterns

- **Azure App Configuration**: Centralized config store + feature flags. Supports Key Vault references and Event Grid change notifications.
- **Azure SignalR Service**: Managed real-time messaging (WebSocket). Use for dashboards, chat, notifications.
- **Azure Web PubSub**: Native WebSocket pub/sub. Use when you don't need the SignalR client SDK.

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.5
- An Azure subscription with **Contributor** access
- Azure CLI authenticated: `az login`
- **Module 00 (Foundation)** deployed — provides Log Analytics workspace

## Deploy

```bash
cd az305-lab/modules/10-app-architecture

cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your foundation outputs and email

terraform init
terraform plan
terraform apply
```

> ⏱️ **Note:** Redis Cache and APIM Consumption can take 10–20 minutes to provision.

## Inputs

| Variable | Type | Default | Description |
|---|---|---|---|
| `location` | string | `"eastus"` | Azure region |
| `prefix` | string | `"az305-lab"` | Naming prefix for all resources |
| `foundation_resource_group_name` | string | `""` | Foundation resource group name |
| `log_analytics_workspace_id` | string | `""` | Log Analytics workspace ID for diagnostics |
| `apim_publisher_name` | string | `"AZ-305 Lab"` | APIM publisher name |
| `apim_publisher_email` | string | `"admin@example.com"` | APIM publisher email |
| `tags` | map(string) | Lab defaults | Tags applied to all resources |

## Outputs

| Output | Description |
|---|---|
| `resource_group_name` | Name of the app architecture resource group |
| `event_grid_topic_endpoint` | Event Grid topic endpoint URL |
| `event_hubs_namespace_name` | Event Hubs namespace name |
| `service_bus_namespace_name` | Service Bus namespace name |
| `apim_gateway_url` | API Management gateway URL |
| `apim_name` | API Management instance name |
| `redis_hostname` | Redis Cache hostname |
| `redis_port` | Redis Cache SSL port |

## Dependencies

| Module | What It Provides |
|---|---|
| **00-foundation** | Log Analytics workspace for diagnostic settings |

## Estimated Cost

| Resource | Estimated Daily Cost |
|---|---|
| Event Grid Topic | < $0.01 (pay per operation) |
| Event Hubs Standard (1 TU) | ~$0.72 |
| Service Bus Standard | ~$0.33 |
| Redis Cache Basic C0 | ~$0.55 |
| API Management Consumption | $0.00 (pay per call) |
| Event Grid Subscription | < $0.01 |
| **Total** | **~$2/day** |

> **💡 Tip:** Run `terraform destroy` when not actively studying to avoid charges.

## Exam Study Questions

1. **A company needs to process financial transactions in strict order with guaranteed delivery. Which messaging service should they use?**
   → Service Bus with sessions (FIFO ordering + exactly-once delivery)

2. **An IoT platform needs to ingest 5 million events per second from devices. Which service?**
   → Event Hubs (designed for high-throughput streaming, partitioned consumers)

3. **You need to trigger an Azure Function when a blob is uploaded to Storage. Which service?**
   → Event Grid (reacts to Azure resource events, push-based delivery)

4. **An application needs a simple message queue with >100GB capacity. Which service?**
   → Storage Queue (supports large queue sizes at lower cost)

5. **Which APIM tier supports VNet integration and multi-region deployment?**
   → Premium tier (also provides 99.99% SLA and availability zones)

6. **What caching pattern should you use for a read-heavy application?**
   → Cache-Aside: check cache first, on miss read DB and populate cache
