# Module 12 — Migration

> **AZ-305 Exam Domain:** Design Infrastructure — **5–10% of exam weight**

🟡 **Partially Deployable** — Azure Migrate, RSV, DMS, storage, and the simulated VM all deploy successfully. However, full migration exercises (discovery, assessment, replication, cutover) require actual source workloads and on-premises appliance deployment.

## What This Module Deploys

| Resource | Name Pattern | Purpose |
|---|---|---|
| Resource Group | `az305-lab-migration-rg` | Dedicated RG for migration resources |
| Azure Migrate Project | `az305-lab-migrate-*` | Central hub for discovery and assessment |
| Recovery Services Vault | `az305-lab-migration-rsv-*` | Azure Site Recovery for VM migration |
| Database Migration Service | `az305-lab-dms-*` | DMS (Standard) for database migration |
| Storage Account | `az305-labmigration*` | Staging storage for migration data |
| Storage Container | `migration-staging` | Blob container for migration artifacts |
| Linux VM (B1s) | `az305-lab-onprem-sim-*` | Simulated on-premises workload (nginx) |
| VM Extension | `install-webserver` | Custom script installing nginx |

**Estimated cost:** ~$1.50/day (DMS Standard ~$0.40/hr when active, B1s VM ~$0.01/hr, RSV + storage minimal)

> ⚠️ **Cost note:** DMS Standard is billed while provisioned. Destroy when not actively studying migration topics.

## Cloud Adoption Framework (CAF) Overview

The CAF provides a structured approach to cloud adoption. AZ-305 focuses on the **Migrate** phase:

```
Strategy → Plan → Ready → MIGRATE → Innovate → Govern → Manage
                    ↑                              ↑
              Landing Zones                  Policy & Cost
              (Modules 00-01)              (Modules 01, 04)
```

| Phase | Key Activities | Lab Modules |
|---|---|---|
| Strategy | Define motivations, business outcomes | — |
| Plan | Digital estate assessment, skills readiness | — |
| Ready | Landing zone deployment, Azure setup | 00, 01 |
| **Migrate** | **Assess, migrate, optimize workloads** | **12 (this)** |
| Innovate | Build cloud-native solutions | 10, 09 |
| Govern | Policy, compliance, cost management | 01, 04 |
| Manage | Operations, monitoring, optimization | 04, 05 |

## The 5 Rs of Migration — Critical Exam Topic

| Strategy | Target | Effort | Downtime | When to Use |
|---|---|---|---|---|
| **Rehost** (Lift & Shift) | IaaS (VMs) | Low | Minutes (ASR) | Time-sensitive, low-risk migration |
| **Refactor** (Replatform) | PaaS | Medium | Variable | Want managed services, minor code changes |
| **Rearchitect** | Cloud-native | High | Planned | Need scalability, resilience, modern patterns |
| **Rebuild** | Cloud-native | Very High | Planned | Legacy app with excessive technical debt |
| **Replace** | SaaS | Low | Cutover | Commodity workload, SaaS alternative exists |

> 💡 **Exam tip:** The exam frequently presents scenarios asking you to choose the right migration strategy. Key decision factors: timeline, budget, application complexity, and business requirements.

## Migration Tool Comparison

| Tool | Use Case | Migration Type |
|---|---|---|
| **Azure Migrate** | Central hub — discovery, assessment, server migration | Rehost, Refactor |
| **Azure Site Recovery** | VM replication and migration with test failover | Rehost |
| **Database Migration Service** | Database migration (online/offline) | Refactor |
| **App Service Migration Asst.** | Web app migration to App Service | Refactor |
| **Data Migration Assistant** | SQL Server assessment and compatibility | Assessment |
| **Azure Data Box** | Offline data transfer (>40 TB) | Data migration |
| **AzCopy** | Online data transfer (blobs, files) | Data migration |
| **Azure Import/Export** | Ship your own drives to Azure | Data migration |

### Online vs Offline Database Migration

| | Online | Offline |
|---|---|---|
| **Downtime** | Seconds–minutes | Hours (depends on size) |
| **DMS SKU** | Premium | Standard |
| **Sync mode** | Continuous (CDC) | One-time |
| **Best for** | Production databases | Dev/test, maintenance windows |
| **Complexity** | Higher | Lower |

### Data Transfer Decision Guide

| Dataset Size | Network Speed | Recommended Tool |
|---|---|---|
| < 10 TB | Good (>100 Mbps) | AzCopy / Storage Explorer |
| 10–40 TB | Good | AzCopy with parallel transfers |
| 40–80 TB | Any | Azure Data Box |
| 80 TB–1 PB | Any | Azure Data Box Heavy |
| Budget-constrained | Any | Azure Import/Export (own drives) |

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.5
- An Azure subscription with **Contributor** access
- Azure CLI authenticated: `az login`
- Foundation module deployed (Module 00) — provides VNet and subnets

## Usage

```bash
cd az305-lab/modules/12-migration
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your foundation outputs:
#   terraform -chdir=../00-foundation output
terraform init
terraform plan
terraform apply
```

### Verify Deployment

```bash
# Check Azure Migrate project
az migrate project list -g az305-lab-migration-rg -o table

# Check the simulated VM's web server
VM_IP=$(terraform output -raw simulated_vm_ip)
curl http://$VM_IP  # from a VM in the same VNet

# Save SSH key for VM access
terraform output -raw ssh_private_key > ~/.ssh/onprem-sim.pem
chmod 600 ~/.ssh/onprem-sim.pem
ssh -i ~/.ssh/onprem-sim.pem azureuser@$VM_IP
```

## Clean Up

```bash
terraform destroy
```

## Inputs

| Variable | Type | Default | Description |
|---|---|---|---|
| `location` | `string` | `"eastus"` | Azure region for all resources |
| `prefix` | `string` | `"az305-lab"` | Naming prefix for resources |
| `foundation_resource_group_name` | `string` | `"az305-lab-foundation-rg"` | Foundation RG name |
| `vnet_id` | `string` | — | Shared VNet resource ID |
| `migration_subnet_id` | `string` | — | Migration subnet resource ID |
| `log_analytics_workspace_id` | `string` | — | Log Analytics workspace ID |
| `admin_ssh_public_key` | `string` | `""` | Optional SSH public key (auto-generated if empty) |
| `auto_shutdown_time` | `string` | `"2200"` | VM auto-shutdown time (HHMM, UTC) |
| `tags` | `map(string)` | AZ-305 defaults | Tags applied to every resource |

## Outputs

| Output | Description |
|---|---|
| `resource_group_name` | Migration resource group name |
| `migrate_project_name` | Azure Migrate project name |
| `recovery_vault_name` | Recovery Services Vault name |
| `dms_name` | Database Migration Service name |
| `staging_storage_account_name` | Staging storage account name |
| `simulated_vm_ip` | Private IP of the simulated on-premises VM |
| `ssh_private_key` | SSH private key for VM access (sensitive) |

## Dependencies

| Module | What It Provides |
|---|---|
| **00-foundation** | VNet, migration subnet (10.0.11.0/24), Log Analytics workspace |

## Estimated Cost

| Resource | Estimated Cost |
|---|---|
| DMS Standard (1 vCore) | ~$0.40/hr when active |
| B1s VM | ~$0.01/hr |
| Recovery Services Vault | ~$0.02/day (no protected items) |
| Storage Account (LRS) | ~$0.02/GB/month |
| Azure Migrate Project | Free |
| **Total (idle)** | **~$1.50/day** |

> 💡 Destroy this module when not actively studying migration topics. DMS is the primary cost driver.
