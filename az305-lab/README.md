# AZ-305: Designing Microsoft Azure Infrastructure Solutions — Hands-On Lab

**Based on [John Savill's AZ-305 Study Cram](https://www.youtube.com/watch?v=vq9LuCM4YP4)**

---

## Overview

This repository provides a **complete hands-on lab environment** for preparing for the [AZ-305 exam](https://learn.microsoft.com/en-us/credentials/certifications/exams/az-305/). Every module is backed by production-grade Terraform IaC that you can deploy, explore, and tear down in your own Azure subscription.

What's included:

- **13 deployable modules** covering all four AZ-305 exam domains
- **Terraform configurations** with sensible defaults and full parameterization
- **Guided exercises** that walk through real design decisions tested on the exam
- **Cost management scripts** so you can pause/resume resources and keep spend under control
- **Prerequisite checks** to validate your environment before you start

Whether you're doing a weekend study sprint or a multi-week deep dive, the lab is designed to be deployed selectively or end-to-end.

---

## Quick Links

| Resource | Link |
|----------|------|
| 📺 AZ-305 Cram Video | <https://www.youtube.com/watch?v=vq9LuCM4YP4> |
| 📖 AZ-305 Study Guide | <https://learn.microsoft.com/en-us/credentials/certifications/resources/study-guides/az-305> |
| 🧪 Practice Assessment | <https://learn.microsoft.com/en-us/credentials/certifications/exams/az-305/practice/assessment?assessment-type=practice&assessmentId=15> |
| 🎫 Exam Registration | <https://learn.microsoft.com/en-us/credentials/certifications/exams/az-305/> |
| 🖥️ Exam Sandbox | <https://aka.ms/examdemo> |
| 🏅 Azure Solutions Architect Certification | <https://learn.microsoft.com/en-us/credentials/certifications/azure-solutions-architect/> |
| 📂 John Savill's Certification Materials | <https://github.com/johnthebrit/CertificationMaterials> |
| 🚀 OnBoard to Azure | <https://learn.onboardtoazure.com> |

---

## Exam Objectives Coverage Map

The AZ-305 exam is divided into four weighted domains. Every domain is covered by at least one lab module.

| Exam Domain | Weight | Modules |
|-------------|--------|---------|
| Design identity, governance, and monitoring solutions | 25–30% | 01-governance, 02-identity, 03-keyvault, 04-monitoring |
| Design data storage solutions | 20–25% | 06-storage, 07-databases, 08-data-integration |
| Design business continuity solutions | 15–20% | 05-ha-dr |
| Design infrastructure solutions | 30–35% | 09-compute, 10-app-architecture, 11-networking, 12-migration |

---

## Prerequisites

| Requirement | Minimum Version / Details |
|-------------|--------------------------|
| Azure subscription | Enterprise recommended; Pay-As-You-Go works |
| Azure CLI | >= 2.50 |
| Terraform | >= 1.5 |
| Git | Any recent version |
| jq | Any recent version |
| Bash shell | macOS/Linux terminal or WSL2 on Windows |
| Permissions | **Contributor** + **User Access Administrator** on the target subscription |

Run the automated check to verify everything is in place:

```bash
./prerequisites/check-prerequisites.sh
```

---

## Quick Start

```bash
# 1. Clone the repository
git clone <repo-url>
cd az305-lab

# 2. Verify prerequisites
./prerequisites/check-prerequisites.sh

# 3. Deploy the foundation module (shared resources used by other modules)
cd modules/00-foundation
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your subscription ID, region, and naming prefix
terraform init && terraform plan && terraform apply

# 4. Deploy any additional module
cd ../01-governance
cp terraform.tfvars.example terraform.tfvars
terraform init && terraform plan && terraform apply
```

> **Tip:** Module `00-foundation` deploys shared resources (resource group, networking baseline, tags) that other modules reference. Always deploy it first.

---

## Module Overview

| Module | Topics | Exam Domain | Est. Time | Est. Daily Cost |
|--------|--------|-------------|-----------|-----------------|
| **00-foundation** | Shared resources, resource group, tagging, naming | Foundation | 10 min | $0.50 |
| **01-governance** | Management groups, Azure Policy, RBAC, Blueprints | Identity / Governance (25–30%) | 20 min | $0.10 |
| **02-identity** | Entra ID, Conditional Access, B2B/B2C, PIM | Identity / Governance | 30 min | $0.10 |
| **03-keyvault** | Key Vault, managed identity, certificate rotation | Identity / Governance | 15 min | $0.50 |
| **04-monitoring** | Azure Monitor, Log Analytics, alerts, dashboards | Identity / Governance | 25 min | $2.00 |
| **05-ha-dr** | Availability Sets/Zones, Load Balancer, ASR, Backup | Business Continuity (15–20%) | 45 min | $4.00 |
| **06-storage** | Blob, Files, Disks, replication, lifecycle management | Data Storage (20–25%) | 30 min | $1.50 |
| **07-databases** | Azure SQL, Cosmos DB, replication, consistency models | Data Storage | 30 min | $3.00 |
| **08-data-integration** | Data Factory, Data Lake, Synapse pipelines | Data Storage | 20 min | $1.00 |
| **09-compute** | VMs, App Service, ACI, Functions, scale sets | Infrastructure (30–35%) | 40 min | $3.50 |
| **10-app-architecture** | Event Grid, Service Bus, API Management, Logic Apps | Infrastructure | 25 min | $2.00 |
| **11-networking** | VNets, peering, VPN Gateway, Firewall, Front Door | Infrastructure | 35 min | $3.00 |
| **12-migration** | Azure Migrate, Database Migration Service, ASR | Infrastructure | 20 min | $1.50 |

---

## Estimated Total Cost

| Scenario | Estimated Daily Cost |
|----------|---------------------|
| All modules running simultaneously | ~$8–15/day |
| Pause scripts active (non-compute resources only) | ~$2–4/day |
| Single module deployed for study | ~$0.10–4.00/day |
| Everything destroyed | $0.00 |

> Costs are estimates based on East US pricing. Actual costs vary by region, SKU tier, and data volume. Always set a **budget alert** in your subscription.

---

## Cost Management

Keeping lab costs low is a first-class concern:

- **Pause/resume scripts** — Stop VMs, scale down databases, and disable expensive features without destroying state:
  ```bash
  ./scripts/pause-all.sh      # Pause all running resources
  ./scripts/resume-all.sh     # Resume when you're ready to study
  ```
- **Per-module teardown** — Destroy a single module when you're done with that topic:
  ```bash
  ./scripts/destroy-module.sh 05-ha-dr
  ```
- **Full teardown** — Remove everything in one command:
  ```bash
  ./scripts/destroy-all.sh
  ```

See [COST-ESTIMATE.md](COST-ESTIMATE.md) for a detailed per-resource cost breakdown and optimization tips.

---

## Project Structure

```
az305-lab/
├── README.md                          # This file
├── COST-ESTIMATE.md                   # Detailed cost breakdown
├── prerequisites/
│   └── check-prerequisites.sh         # Environment validation script
├── modules/
│   ├── 00-foundation/                 # Shared resources (deploy first)
│   ├── 01-governance/                 # Management groups, Policy, RBAC
│   ├── 02-identity/                   # Entra ID, Conditional Access
│   ├── 03-keyvault/                   # Key Vault, managed identity
│   ├── 04-monitoring/                 # Monitor, Log Analytics, alerts
│   ├── 05-ha-dr/                      # HA, load balancing, backup/DR
│   ├── 06-storage/                    # Blob, Files, disks
│   ├── 07-databases/                  # SQL, Cosmos DB
│   ├── 08-data-integration/           # Data Factory, Data Lake
│   ├── 09-compute/                    # VMs, App Service, containers
│   ├── 10-app-architecture/           # Events, messaging, APIM
│   ├── 11-networking/                 # VNets, VPN, Firewall, Front Door
│   └── 12-migration/                  # Azure Migrate, DMS
├── exercises/                         # Guided hands-on exercises
├── scripts/
│   ├── pause-all.sh                   # Pause resources to save costs
│   ├── resume-all.sh                  # Resume paused resources
│   ├── destroy-all.sh                 # Tear down all modules
│   └── destroy-module.sh              # Tear down a single module
└── assets/                            # Diagrams, images, reference files
```

---

## Usage Patterns

### Sequential (Full Lab)

Deploy all modules in order from `00-foundation` through `12-migration`. This gives you the complete lab experience and mirrors the exam's breadth of coverage.

```bash
for module in modules/*/; do
  echo "Deploying $module..."
  cd "$module"
  terraform init && terraform apply -auto-approve
  cd ../..
done
```

### Selective (Domain-Focused)

Deploy only the modules that cover the exam domain you're studying:

- **Identity & Governance:** `00-foundation` → `01` → `02` → `03` → `04`
- **Data Storage:** `00-foundation` → `06` → `07` → `08`
- **Business Continuity:** `00-foundation` → `05`
- **Infrastructure:** `00-foundation` → `09` → `10` → `11` → `12`

### Study Sprint (Cost-Optimized)

Deploy a module, work through the exercises, then destroy it before moving on. This keeps costs to a minimum and is ideal for focused exam review sessions.

```bash
# Deploy
cd modules/05-ha-dr
terraform init && terraform apply

# Study and explore...

# Destroy when done
terraform destroy -auto-approve
```

---

## Cleanup

Remove all lab resources when you're finished:

```bash
# Destroy everything (all modules, in reverse order)
./scripts/destroy-all.sh

# Or destroy a single module
./scripts/destroy-module.sh <module-name>
# Example: ./scripts/destroy-module.sh 07-databases
```

> **Important:** Always run cleanup when you're done studying to avoid unexpected Azure charges. The `destroy-all.sh` script tears down modules in reverse dependency order so that shared resources in `00-foundation` are removed last.

---

## License

This project is licensed under the [MIT License](LICENSE).

---

## Acknowledgments

- **[John Savill](https://www.youtube.com/@yourITguru)** — AZ-305 Study Cram video and certification materials that form the foundation for this lab's content structure and topic coverage.
- **[Microsoft Learn](https://learn.microsoft.com)** — Official AZ-305 study guide, documentation, and practice assessments.
- **Azure community contributors** — For patterns, best practices, and feedback that shaped these lab exercises.
