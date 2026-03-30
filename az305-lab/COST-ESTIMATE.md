# AZ-305 Lab — Cost Estimate

> **Region:** East US | **Currency:** USD | **Pricing:** Approximate as of 2025
> All costs are estimates based on Azure public pricing. Actual costs may vary.

---

## Per-Module Cost Breakdown

| Module | Resource | SKU / Tier | Hourly Cost | Monthly Cost (730h) | Pausable? | Free Tier? |
|--------|----------|-----------|-------------|---------------------|-----------|------------|
| **00 — Foundation** | Log Analytics Workspace | PerGB2018 | — | ~$2.30/GB ingested | No | ✅ 5 GB/month free |
| | VNet, Subnets, NSG | Free | $0 | $0 | — | ✅ |
| | **Module total** | | | **~$2.50** | | |
| **01 — Governance** | Policy definitions/assignments | Free | $0 | $0 | — | ✅ |
| | Custom RBAC roles | Free | $0 | $0 | — | ✅ |
| | Management Group | Free | $0 | $0 | — | ✅ |
| | Resource Locks | Free | $0 | $0 | — | ✅ |
| | **Module total** | | | **~$0** | | |
| **02 — Identity** | Entra ID groups, apps, SPs | Entra ID Free | $0 | $0 | — | ✅ |
| | *(Optional PIM/Access Reviews)* | *Entra ID P2* | — | *$9/user/month* | — | ❌ |
| | **Module total** | | | **~$0** | | |
| **03 — Key Vault** | Key Vault | Standard | — | ~$1/key + $0.03/10K ops | No | ❌ |
| | Private Endpoint | — | $0.01 | ~$7.30 | No | ❌ |
| | Managed Identity | Free | $0 | $0 | — | ✅ |
| | **Module total** | | | **~$15** | | |
| **04 — Monitoring** | Application Insights | Included in LA | — | (see LA ingestion) | — | — |
| | Alert rules | Metric/Log | — | ~$0.10–1.50/rule | No | ❌ |
| | Dashboard | Free | $0 | $0 | — | ✅ |
| | Log Analytics ingestion | PerGB2018 | — | $2.30/GB after free 5 GB | No | ✅ 5 GB |
| | **Module total** | | | **~$50–70** | | |
| **05 — HA/DR** | 3× VM | Standard_B1s | $0.0104 ea | ~$7.59 ea = $22.77 | ✅ Dealloc | ❌ |
| | Public Load Balancer | Standard | $0.025 + rules | ~$18 | No | ❌ |
| | Internal Load Balancer | Standard | $0.025 + rules | ~$18 | No | ❌ |
| | Recovery Services Vault | Standard | — | ~$10 base + $10/instance | No | ❌ |
| | Traffic Manager | — | — | ~$0.75/M queries + $0.54/endpoint | No | ❌ |
| | Public IPs | Standard | — | ~$3.65 each | No | ❌ |
| | **Module total** | | | **~$100–120** | | |
| **06 — Storage** | GPv2 | Standard GRS Hot | — | ~$0.036/GB | No | ❌ |
| | Premium Block Blob | LRS | — | ~$0.15/GB | No | ❌ |
| | Data Lake Gen2 | — | — | ~$0.018/GB | No | ❌ |
| | Managed Disk (Standard HDD) | S4 32 GB | — | ~$1.54 | No | ❌ |
| | Managed Disk (Premium SSD) | P4 32 GB | — | ~$5.28 | No | ❌ |
| | Private Endpoint | — | $0.01 | ~$7.30 | No | ❌ |
| | **Module total** | | | **~$10–20** | | |
| **07 — Databases** | SQL Database | Basic (5 DTU) | — | ~$4.90 | No | ❌ |
| | SQL Database | Serverless GP_S_Gen5_1 | $0.5124/vCore-hr | Auto-pauses | ✅ Auto-pause | ❌ |
| | SQL Elastic Pool | BasicPool (50 eDTU) | — | ~$75–149 ⚠️ | No | ❌ |
| | Cosmos DB | Serverless | — | ~$0.25/M RU + $0.25/GB | ✅ Serverless | ❌ |
| | Private Endpoint | — | $0.01 | ~$7.30 | No | ❌ |
| | **Module total** | | | **~$30–50** | | |
| **08 — Data Integration** | Data Factory | — | — | ~$1/1K activity runs | ✅ Idle ≈ free | ❌ |
| | Data Lake Gen2 Storage | — | — | ~$1–2 (minimal data) | No | ❌ |
| | Event Grid | — | — | ~$0.60/M operations | No | ❌ |
| | **Module total** | | | **~$5–10** | | |
| **09 — Compute** | VM | Standard_B1s | $0.0104 | ~$7.59 | ✅ Dealloc | ❌ |
| | App Service | B1 | $0.018 | ~$13.14 | No | ❌ |
| | Container Instance | 0.5 vCPU / 0.5 GB | — | ~$13 (always-on) | ✅ Stop | ❌ |
| | Container Registry | Basic | — | ~$5 | No | ❌ |
| | Function App | Consumption | — | ~$0 | ✅ | ✅ 1M exec/mo |
| | Batch Account | Free (pools cost) | $0 | $0 | — | ✅ |
| | **Module total** | | | **~$60–80** | | |
| **10 — App Architecture** | Event Hubs | Standard (1 TU) | — | ~$22 | No | ❌ |
| | Service Bus | Standard | — | ~$10 | No | ❌ |
| | API Management | Consumption | — | ~$3.50/M calls | ✅ Idle ≈ free | ❌ |
| | Redis Cache | Basic C0 | — | ~$16 | No | ❌ |
| | **Module total** | | | **~$60–80** | | |
| **11 — Networking** | VNet Peering | — | — | ~$0.01/GB transferred | No | ❌ |
| | NSG, ASG, Route Table | Free | $0 | $0 | — | ✅ |
| | Public IP | Standard | — | ~$3.65 | No | ❌ |
| | DNS Zone | — | — | ~$0.50 | No | ❌ |
| | **Module total (base)** | | | **~$5** | | |
| | ⚠️ Azure Firewall | Standard | $1.25 | ~$912 | No | ❌ |
| | ⚠️ VPN Gateway | VpnGw1 | $0.19 | ~$138 | No | ❌ |
| | ⚠️ Bastion | Basic | $0.19 | ~$139 | No | ❌ |
| **12 — Migration** | Database Migration Service | Standard | $0.37 | ~$271 ⚠️ | ✅ Destroy | ❌ |
| | Recovery Services Vault | Standard | — | ~$10 | No | ❌ |
| | VM | Standard_B1s | $0.0104 | ~$7.59 | ✅ Dealloc | ❌ |
| | Storage Account | GPv2 LRS | — | ~$1 | No | ❌ |
| | **Module total** | | | **~$40–50** | | |

> ⚠️ = High-cost optional resource. Commented out by default in Terraform configs.

---

## Cost Summary

| Scenario | Monthly Estimate | Daily Estimate |
|----------|-----------------|----------------|
| All modules deployed (no optionals) | ~$400–550 | ~$13–18 |
| With pause scripts active (VMs off, serverless paused) | ~$150–200 | ~$5–7 |
| Fully paused (storage, IPs, always-on services only) | ~$100–150 | ~$3–5 |

### What Keeps Costing When "Paused"

Even with all VMs deallocated and serverless resources paused, you still pay for:

- Public IP addresses (Standard SKU)
- Load Balancers (Standard SKU)
- Managed Disks (allocated capacity)
- Key Vault (keys and certificates)
- Private Endpoints
- Event Hubs / Service Bus (base tier)
- Redis Cache (always-on)
- Container Registry (base tier)
- DNS Zones
- Storage accounts (allocated capacity)

---

## Recommended Study Schedule

Deploy modules incrementally and destroy after completing exercises to minimize cost:

| Week | Modules | Focus Area | Est. Daily Cost | Destroy After? |
|------|---------|------------|-----------------|----------------|
| 1 | 00–04 | Identity, Governance, Monitoring | ~$3/day | ✅ |
| 2 | 05–06 | HA/DR, Storage | ~$5/day | ✅ |
| 3 | 07–08 | Databases, Data Integration | ~$4/day | ✅ |
| 4 | 09–12 | Compute, Apps, Networking, Migration | ~$8/day | ✅ |

**Total estimated study cost following this schedule: ~$100–150**

---

## Cost Optimization Tips

1. **Run `pause-resources.sh` daily** when done studying — deallocates VMs, pauses serverless databases
2. **Deploy modules one at a time** and `terraform destroy` after completing exercises
3. **Set a budget alert** at $50 (see below) to catch runaway costs early
4. **Elastic Pool and DMS are the biggest cost surprises** — deploy only when actively exercising those topics
5. **Firewall / VPN Gateway / Bastion** are commented out by default — only enable when needed for specific exercises
6. **All VMs have auto-shutdown** configured at 22:00 UTC
7. **SQL Serverless auto-pauses** after idle period — leverage this by working on one database exercise at a time
8. **Cosmos DB Serverless** only charges for actual request units consumed

---

## Budget Alert Setup

Set a $50 monthly budget alert to catch unexpected costs:

```bash
az consumption budget create \
  --amount 50 \
  --budget-name "AZ305-Lab-Budget" \
  --category cost \
  --time-grain monthly \
  --start-date "$(date -u +%Y-%m-01)" \
  --end-date "$(date -u -v+3m +%Y-%m-01)" \
  --resource-group az305-lab-foundation-rg
```

Or set up in the Azure Portal:

1. Navigate to **Cost Management + Billing → Budgets**
2. Click **+ Add**
3. Set amount to **$50**, time grain to **Monthly**
4. Add notification at **80%** and **100%** thresholds
5. Set email recipients to your alert address
