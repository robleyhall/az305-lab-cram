# AZ-305: Designing Microsoft Azure Infrastructure Solutions — Hands-On Lab Study Guide

## Based on John Savill's AZ-305 Study Cram

> **Video Source:** [AZ-305 Study Cram by John Savill](https://www.youtube.com/watch?v=vq9LuCM4YP4) (3h 38m)
>
> **Exam:** [AZ-305 — Designing Microsoft Azure Infrastructure Solutions](https://learn.microsoft.com/en-us/credentials/certifications/exams/az-305/)

---

## About This Lab

This hands-on lab guide transforms John Savill's comprehensive AZ-305 certification cram session into a deployable learning environment. Each module deploys real Azure resources that you can inspect, configure, and experiment with — turning theoretical knowledge into practical experience.

The lab covers all four exam domains with 13 Terraform modules, 78 exercises at multiple difficulty levels, and exam-style practice questions.

## How to Use This Guide

1. **Follow sequentially** — modules build on each other, starting with the foundation
2. **Deploy each module** using the provided Terraform commands
3. **Read the Concepts section** to understand what you're deploying and why
4. **Complete the Explore & Verify section** — inspect deployed resources in the **Azure Portal** and with CLI
5. **Work through the Exercises** — start with 🟢 Guided, progress to 🔴 Challenge
6. **Review Key Takeaways** and exam tips before moving on
7. **Use `./scripts/pause-resources.sh`** when stepping away to minimize costs

## Prerequisites

| Tool | Minimum Version | Check Command |
|------|----------------|---------------|
| Azure CLI | 2.50+ | `az --version` |
| Terraform | 1.5+ | `terraform --version` |
| Git | any | `git --version` |
| jq | any | `jq --version` |

- Azure subscription with **Contributor + User Access Administrator** roles
- Run `./prerequisites/check-prerequisites.sh` to verify everything

## Exam Objectives Coverage Map

| Exam Domain | Weight | Lab Modules | Key Topics |
|---|---|---|---|
| Design identity, governance, and monitoring solutions | 25–30% | 01, 02, 03, 04 | Management groups, Policy, RBAC, Entra ID, Key Vault, Monitor |
| Design data storage solutions | 20–25% | 06, 07, 08 | Storage accounts, SQL, CosmosDB, Data Factory, Data Lake |
| Design business continuity solutions | 15–20% | 05 | Availability sets/zones, load balancers, backup, DR |
| Design infrastructure solutions | 30–35% | 09, 10, 11, 12 | Compute, messaging, networking, migration |

---

## Module 00: Foundation Setup

### Learning Objectives

After completing this module, you will be able to:
- Explain the Azure management hierarchy (tenant → management groups → subscriptions → resource groups)
- Design a VNet address space with subnet planning for multiple workloads
- Configure a shared Log Analytics workspace for centralized monitoring

### Exam Relevance

**Domain:** Foundation for all Azure architecture design
**Key exam concept:** Resource groups are lifecycle boundaries, NOT communication boundaries. A resource group's region is metadata only — it does not restrict where resources inside it can be created.

### Concepts Overview

Azure organizes resources in a clear hierarchy. At the top is your **Entra ID tenant** (identity boundary). Below that, **management groups** provide governance scope (up to 6 levels deep). **Subscriptions** are the billing and access boundary. **Resource groups** are logical containers for resources with a common lifecycle.

> 💡 **Exam Tip:** Tags are NOT inherited from resource groups to resources. Use Azure Policy to copy tags from resource groups if needed.

This module creates a shared Virtual Network (10.0.0.0/16) with dedicated subnets for each lab module, a Network Security Group, and a Log Analytics Workspace that all other modules send diagnostics to.

**Cram Session Reference:** 8:00–13:52 (Core Azure structure)

### Deploy

```bash
cd modules/00-foundation
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your preferences
terraform init
terraform plan
terraform apply
```

### Explore & Verify

**In the Azure Portal:**
1. Navigate to **Resource Groups** → find `az305-lab-foundation-rg-*`
2. Click the resource group → **Tags** tab → verify Lab, Module, CostCenter tags
3. Navigate to **Virtual Networks** → inspect the VNet and its 14 subnets
4. Navigate to **Log Analytics workspaces** → verify the workspace is active

**With CLI:**
```bash
# List resources in foundation
az resource list --resource-group $(terraform output -raw resource_group_name) -o table

# Inspect VNet subnets
az network vnet subnet list --resource-group $(terraform output -raw resource_group_name) \
  --vnet-name $(terraform output -raw vnet_name) -o table
```

### Key Takeaways

- Resource group region = metadata location, not a constraint on resource placement
- Tags are not inherited — use Policy to enforce tag inheritance
- A well-planned VNet with pre-allocated subnets avoids address space conflicts later
- Log Analytics workspace-per-region is a common design pattern for cost and performance

---

## Module 01: Governance & Compliance

### Learning Objectives

- Design a management group hierarchy for enterprise governance
- Implement Azure Policy to enforce organizational standards
- Configure RBAC with appropriate scope and granularity
- Understand Blueprints, PIM, and Access Reviews (conceptually)

### Exam Relevance

**Domain:** Design identity, governance, and monitoring solutions (25–30%)
**Skills measured:** Recommend a structure for management groups/subscriptions/resource groups, recommend a solution for managing compliance

### Concepts Overview

Governance in Azure revolves around three pillars:
- **Policy** = WHAT you can do (guard rails)
- **RBAC** = WHO can do it (permissions)
- **Budget** = HOW MUCH (cost controls)

**Azure Policy** uses definitions (individual rules) grouped into **initiatives** (collections of rules). Effects include: `Audit` (log non-compliance), `Deny` (prevent creation), `DeployIfNotExists` (auto-remediate), `Modify` (add/change properties).

> ⚠️ **Common Mistake:** Policy effects are evaluated in a specific order. `Disabled` → `Append`/`Modify` → `Deny` → `Audit`/`AuditIfNotExists` → `DeployIfNotExists`. A `Deny` effect blocks the operation before `DeployIfNotExists` can fire.

**RBAC** is cumulative — if you have Reader at the subscription and Contributor at the resource group, you effectively have Contributor on that resource group. There is **no deny assignment** except through Blueprints or Managed Applications.

**Privileged Identity Management (PIM)** provides just-in-time role activation — users request elevated access, optionally with MFA and approval, and get it for a limited duration. This is an **Entra ID Premium P2** feature.

**Cram Session Reference:** 7:43–22:40 (Identity, governance, Policy, RBAC, Blueprints)

### Deploy

```bash
cd modules/01-governance
cp terraform.tfvars.example terraform.tfvars
terraform init && terraform plan && terraform apply
```

### Explore & Verify

**In the Azure Portal:**
1. Navigate to **Policy** → **Compliance** → review compliance state for each assignment
2. Click on a non-compliant assignment → see which resources are non-compliant and why
3. Navigate to **Policy** → **Definitions** → filter to "Custom" → inspect the tag and SKU policies
4. Navigate to the governance resource group → **Access control (IAM)** → **Roles** → search for the custom "Lab Reader Plus" role → inspect its permissions

**Design Scenario Exercise:**
Your organization has 3 departments (Engineering, Sales, Finance), each with Dev and Prod workloads. Design the management group hierarchy and identify where you would apply: (a) a policy restricting VM sizes, (b) RBAC for department admins, (c) a budget alert.

### Key Takeaways

- Policy inheritance flows down: Management Group → Subscription → Resource Group → Resource
- RBAC is cumulative (additive) — no deny except via Blueprints
- PIM = just-in-time access (P2 feature) — know when to recommend it
- Blueprints = resource groups + ARM templates + RBAC + Policy as a deployable package
- For the exam: if they ask about "ensuring compliance" → Policy; "controlling who" → RBAC; "time-limited access" → PIM

---

## Module 02: Identity & Access

### Learning Objectives

- Compare identity synchronization methods (Password Hash Sync, Pass-Through Auth, Federation)
- Explain B2B vs B2C identity models
- Design Conditional Access policies
- Understand when to recommend PIM and Access Reviews

### Exam Relevance

**Domain:** Design identity, governance, and monitoring solutions (25–30%)
**Skills measured:** Recommend an authentication solution, recommend an identity management solution

### Concepts Overview

**Identity synchronization** from on-premises AD to Entra ID uses **Entra Connect** (or Cloud Sync). Three authentication methods:

| Method | How It Works | Recommendation |
|--------|-------------|----------------|
| **Password Hash Sync (PHS)** | Hash of hash replicated to cloud | ✅ Recommended — enables leaked credential detection |
| **Pass-Through Auth (PTA)** | Auth validated on-premises in real-time | When passwords must never leave on-prem |
| **Federation (ADFS)** | Redirects to on-prem federation server | Legacy/complex — smartcard, 3rd-party MFA |

> 💡 **Exam Tip:** Microsoft recommends PHS even alongside other methods. It enables Identity Protection to detect leaked credentials on the dark web — a frequent exam point.

**B2B vs B2C:**
- **B2B:** Invite external partners as guest users in YOUR tenant. They authenticate with their home identity provider.
- **B2C:** Consumer-facing identity in a SEPARATE tenant. Supports social logins (Google, Facebook, etc.).

**Conditional Access** (P1+): Evaluates conditions (user, device, location, risk level) → applies controls (MFA, block, compliant device required). Policies are evaluated together — all applicable policies must be satisfied.

**PIM** (P2): Just-in-time role activation. **Access Reviews** (P2): Periodic validation that users still need their access.

**Cram Session Reference:** 22:40–38:50 (Azure AD and identity, application identities)

### Deploy

```bash
cd modules/02-identity
cp terraform.tfvars.example terraform.tfvars
terraform init && terraform plan && terraform apply
```

### Explore & Verify

**In the Azure Portal:**
1. Navigate to **Entra ID** → **Groups** → find the three az305-lab groups → inspect membership type (Assigned vs Dynamic)
2. Navigate to **App registrations** → find the az305-lab app → examine API permissions, certificates & secrets
3. Navigate to the identity resource group → **Access control (IAM)** → verify role assignments for the groups

**Design Scenario Exercise:**
A company with 5,000 employees uses on-premises Active Directory. They need: SSO to Azure resources, leaked credential detection, and MFA for admin access. Which sync method, which Entra ID tier, and which features would you recommend?

### Key Takeaways

- PHS is recommended even with other auth methods (enables identity protection)
- Seamless SSO provides transparent sign-in from domain-joined devices
- B2B = partners in your tenant; B2C = consumers in separate tenant
- Conditional Access requires P1; PIM and Access Reviews require P2
- Managed Identity > Service Principal > Shared keys (in order of preference)

---

## Module 03: Application Identity & Key Vault

### Learning Objectives

- Design a secrets management strategy using Key Vault
- Compare managed identity types (system-assigned vs user-assigned)
- Implement private endpoint connectivity pattern
- Choose between Key Vault access policies and RBAC authorization

### Exam Relevance

**Domain:** Design identity, governance, and monitoring solutions (25–30%)
**Skills measured:** Recommend a solution to manage secrets, certificates, and keys

### Concepts Overview

**Azure Key Vault** stores three types of items:
- **Secrets:** Connection strings, passwords, API keys
- **Keys:** Cryptographic keys for encryption/signing (HSM-backed available)
- **Certificates:** TLS/SSL certificates with auto-renewal

**Access Models:**
| Model | How It Works | Recommendation |
|-------|-------------|----------------|
| **Vault Access Policy** (legacy) | Per-vault policy granting permissions to an identity | Legacy approach |
| **RBAC Authorization** | Standard Azure RBAC roles (Key Vault Administrator, Secrets User, etc.) | ✅ Recommended — consistent with Azure RBAC, more granular |

> ⚠️ **Common Mistake:** Once purge protection is enabled on a Key Vault, it CANNOT be disabled. Soft-deleted vaults with purge protection cannot be purged until the retention period expires. For a lab, we keep purge protection off.

**Managed Identity** eliminates the need for credentials in code:
- **System-assigned:** Created with and tied to a specific resource. Deleted when the resource is deleted.
- **User-assigned:** Independent lifecycle. Can be assigned to multiple resources. Better for shared access patterns.

**Private Endpoints** provide a private IP address in your VNet for the Key Vault, eliminating public internet exposure. DNS resolution is handled by a Private DNS Zone.

**Cram Session Reference:** 34:48–43:58 (Application identities, managed identity, Key Vault)

### Deploy

```bash
cd modules/03-keyvault
cp terraform.tfvars.example terraform.tfvars
terraform init && terraform plan && terraform apply
```

### Explore & Verify

**In the Azure Portal:**
1. Navigate to the Key Vault → **Secrets** → view the sample connection string
2. Navigate to **Keys** → inspect the RSA-2048 key
3. Navigate to **Access configuration** → verify RBAC authorization is enabled (not access policies)
4. Navigate to **Networking** → verify private endpoint is connected and firewall rules are set
5. Navigate to **Managed Identities** → find the user-assigned identity → check its role assignments

### Key Takeaways

- RBAC authorization > access policies (modern best practice)
- Managed identity > service principal > shared keys
- System-assigned = lifecycle tied to resource; User-assigned = independent lifecycle
- Private endpoint = private IP in your VNet, no public exposure
- Soft delete is enabled by default; purge protection is a one-way switch

---

## Module 04: Monitoring & Alerting

### Learning Objectives

- Design a monitoring solution using Azure Monitor
- Configure alerts for metrics, logs, and activity events
- Understand Log Analytics workspace design patterns
- Compare Azure Monitor Agent (AMA) vs legacy agents

### Exam Relevance

**Domain:** Design identity, governance, and monitoring solutions (25–30%)
**Skills measured:** Recommend a logging solution, recommend a solution for routing logs, recommend a monitoring solution

### Concepts Overview

**Azure Monitor** collects three types of data:
1. **Platform Metrics:** Numeric time-series data, automatically collected, 93-day retention, free
2. **Resource/Activity Logs:** Structured log data, must be routed to a destination (Log Analytics, Storage, Event Hub)
3. **Application Telemetry:** Via Application Insights (request rates, exceptions, dependencies)

**Log Analytics Workspace Design:**
- Single workspace is simplest but may not meet data residency or access control requirements
- Multi-workspace for: different regions, different access needs, cost isolation
- PerGB2018 pricing: ~$2.30/GB ingested, first 5 GB/month free

> 💡 **Exam Tip:** Azure Monitor Agent (AMA) with Data Collection Rules (DCRs) replaces ALL legacy agents (Log Analytics agent, Diagnostics extension, Telegraf). Always recommend AMA for new deployments.

**Alert Types:**
| Alert Type | Source | Use Case |
|-----------|--------|----------|
| Metric Alert | Platform metrics | CPU > 80%, response time > 2s |
| Log Alert | KQL query results | Error count > threshold |
| Activity Log Alert | Control plane events | Resource deleted, role assigned |

**Cram Session Reference:** 43:58–54:07 (Monitoring, Alerting)

### Deploy

```bash
cd modules/04-monitoring
cp terraform.tfvars.example terraform.tfvars
terraform init && terraform plan && terraform apply
```

### Explore & Verify

**In the Azure Portal:**
1. Navigate to **Monitor** → **Alerts** → review configured alert rules
2. Navigate to **Log Analytics workspace** → **Logs** → run: `Heartbeat | summarize count() by Computer`
3. Navigate to **Application Insights** → explore the Overview dashboard
4. Navigate to **Monitor** → **Action groups** → verify the email action group

**Design Scenario Exercise:**
You're designing monitoring for a 3-tier application (web, API, database) across 2 regions. How many Log Analytics workspaces would you recommend? Where would you route each data type? What alerts would you configure?

### Key Takeaways

- AMA + DCRs replace all legacy monitoring agents
- Metrics are free and automatic; logs require routing configuration
- Log Analytics pricing is per-GB ingested — monitor ingestion volume
- Application Insights is now workspace-based (connects to Log Analytics)
- For the exam: "centralized monitoring" → single workspace; "data residency" → multi-workspace

---

## Module 05: High Availability & Disaster Recovery

### Learning Objectives

- Compare availability sets vs availability zones (SLA implications)
- Design load balancing solutions using the Azure decision tree
- Configure backup and disaster recovery strategies
- Calculate RPO and RTO for different architectures

### Exam Relevance

**Domain:** Design business continuity solutions (15–20%)
**Skills measured:** Recommend a high availability solution for compute, recommend a recovery solution that meets recovery objectives

### Concepts Overview

**Availability Options (CRITICAL exam topic):**

| Option | Protection Against | SLA | Key Constraint |
|--------|-------------------|-----|----------------|
| **Single VM + Premium SSD** | Disk failure | 99.9% | No redundancy |
| **Availability Set** | Rack failure (FD) + maintenance (UD) | 99.95% | Same datacenter |
| **Availability Zone** | Datacenter failure | 99.99% | Cross-datacenter latency |

> ⚠️ **Common Mistake:** You CANNOT place a VM in both an Availability Set AND an Availability Zone. They are mutually exclusive.

**Load Balancer Decision Tree:**

| Service | Layer | Scope | Key Feature |
|---------|-------|-------|-------------|
| **Azure Load Balancer** | 4 (TCP/UDP) | Regional | Internal or public, zone-redundant (Standard) |
| **Application Gateway** | 7 (HTTP/S) | Regional | WAF, SSL offload, URL-based routing |
| **Traffic Manager** | DNS | Global | Multiple routing methods, health checks |
| **Azure Front Door** | 7 (HTTP/S) | Global | WAF + CDN + acceleration, SSL offload |

> 💡 **Exam Tip:** Standard Load Balancer is required for Availability Zones and is zone-redundant by default. Basic LB does NOT support zones.

**Backup & DR:**
- **Azure Backup:** Recovery Services Vault, backup policies, retention schedules
- **Azure Site Recovery (ASR):** VM replication to secondary region, test failover, planned failover
- **RPO** (Recovery Point Objective): How much data loss is acceptable (time between backups)
- **RTO** (Recovery Time Objective): How quickly must the system recover

**Cram Session Reference:** 54:07–1:13:03 (Business continuity, availability, load balancers, backup)

### Deploy

```bash
cd modules/05-ha-dr
cp terraform.tfvars.example terraform.tfvars
terraform init && terraform plan && terraform apply
```

### Explore & Verify

**In the Azure Portal:**
1. Navigate to **Virtual Machines** → click an availability set VM → **Properties** → verify Fault Domain and Update Domain assignment
2. Navigate to the zone VM → **Properties** → verify Availability Zone assignment
3. Navigate to **Load Balancers** → inspect health probes, backend pools, load balancing rules
4. Navigate to **Recovery Services Vault** → **Backup items** → verify VM backup registration
5. Navigate to **Traffic Manager** → inspect endpoints and routing method

**Design Scenario Exercise:**
An e-commerce application requires 99.99% SLA with RPO of 5 minutes and RTO of 1 hour. The application has a web tier, API tier, and database tier. Design the complete HA/DR architecture.

### Key Takeaways

- Know the SLA numbers: 99.9% (single VM), 99.95% (avset), 99.99% (zones)
- Availability Set ≠ Availability Zone — they're mutually exclusive per VM
- Standard LB required for production and zones; Basic LB is being deprecated
- Regional LB (Layer 4) + Global LB (Layer 7) = common multi-tier pattern
- RPO/RTO determine your backup frequency and replication strategy

---

## Module 06: Storage Solutions

### Learning Objectives

- Compare storage replication options and their trade-offs
- Design tiered storage strategies using lifecycle management
- Implement storage security (SAS, encryption, network rules)
- Differentiate between blob types, storage account types, and disk types

### Exam Relevance

**Domain:** Design data storage solutions (20–25%)
**Skills measured:** Recommend a data storage solution to balance features/performance/costs, recommend a solution for data protection

### Concepts Overview

**Storage Replication (CRITICAL exam topic):**

| Option | Copies | Durability | Use Case |
|--------|--------|-----------|----------|
| **LRS** | 3 (single DC) | 99.999999999% (11 9s) | Lowest cost, non-critical data |
| **ZRS** | 3 (across AZs) | 99.9999999999% (12 9s) | Zone-level resilience |
| **GRS** | 6 (LRS + paired region) | 99.99999999999999% (16 9s) | Regional disaster protection |
| **RA-GRS** | 6 (GRS + read secondary) | 16 9s + read access | Read access during regional outage |
| **GZRS** | 6 (ZRS + paired region) | 16 9s | Zone + regional protection |
| **RA-GZRS** | 6 (GZRS + read secondary) | 16 9s + read access | Maximum protection + read access |

**Access Tiers:**
- **Hot:** Frequent access, lowest access cost, highest storage cost
- **Cool:** Infrequent (30-day minimum), lower storage, higher access cost
- **Cold:** Rare access (90-day minimum), even lower storage cost
- **Archive:** Offline (180-day minimum), cheapest storage, hours to rehydrate

> 💡 **Exam Tip:** Data Lake Gen2 = Standard storage account + hierarchical namespace enabled. It provides POSIX-style ACLs and HDFS-compatible access. It's NOT a separate service.

**Managed Disks & VM SLA:**
- Standard HDD, Standard SSD, Premium SSD, Ultra Disk
- Single VM SLA of 99.9% requires **Premium SSD or Ultra Disk**

**Private Endpoint vs Service Endpoint:**
- Service Endpoint: Optimized route over Azure backbone, resource still has public IP
- Private Endpoint: Private IP in your VNet, no public exposure — **preferred**

**Cram Session Reference:** 1:13:03–1:44:30 (Storage account services, managed disks, storage security)

### Deploy

```bash
cd modules/06-storage
cp terraform.tfvars.example terraform.tfvars
terraform init && terraform plan && terraform apply
```

### Explore & Verify

**In the Azure Portal:**
1. Navigate to the GPv2 storage account → **Data management** → **Lifecycle management** → inspect the tiering rules
2. Navigate to **Data protection** → verify soft delete and versioning settings
3. Navigate to **Networking** → examine firewall rules and private endpoint connections
4. Navigate to the Data Lake storage account → **Containers** → note the hierarchical namespace features
5. Compare the three storage accounts' **Redundancy** settings (GRS, LRS, LRS)

**Design Scenario Exercise:**
A company has 50TB of data. First month: accessed daily. Months 2–12: accessed weekly. After 1 year: accessed annually for compliance. Design the storage solution including account type, replication, and lifecycle management.

### Key Takeaways

- Know replication trade-offs: cost ↔ durability ↔ availability ↔ read access
- Data Lake Gen2 = storage account + hierarchical namespace
- Private endpoint > service endpoint for security
- Lifecycle management automates tiering: Hot → Cool → Cold → Archive
- Single VM 99.9% SLA requires Premium SSD or Ultra Disk

---

## Module 07: Database Solutions

### Learning Objectives

- Compare Azure SQL deployment models (Database, Elastic Pool, Managed Instance, VM)
- Choose between DTU and vCore purchasing models
- Design CosmosDB solutions with appropriate consistency levels
- Implement database security and geo-replication

### Exam Relevance

**Domain:** Design data storage solutions (20–25%)
**Skills measured:** Recommend a solution for storing relational data, recommend a database service tier and compute tier

### Concepts Overview

**Azure SQL Decision Tree (CRITICAL exam topic):**

| Deployment | Compatibility | VNet | Use Case |
|-----------|--------------|------|----------|
| **SQL Database** | Subset of SQL Server | No (PE available) | New cloud-native apps, per-database scaling |
| **SQL Elastic Pool** | Same as SQL DB | No (PE available) | Multi-tenant, many small databases sharing resources |
| **SQL Managed Instance** | ~100% SQL Server | Yes (VNet-native) | Lift-and-shift, cross-DB queries, SQL Agent |
| **SQL Server on VM** | 100% SQL Server | Yes | Full OS access, legacy apps, unsupported features |

**DTU vs vCore:**
- **DTU:** Bundled compute (Basic: 5 DTU → Premium: 4000 DTU). Simple, predictable pricing.
- **vCore:** Independent compute/storage. Flexible scaling. Required for Hyperscale.
- **Serverless (vCore):** Auto-scale + auto-pause. Pay per second when active. Ideal for intermittent workloads.

**Hyperscale tier:** Up to 100 TB, rapid scale-out read replicas, near-instant backups via snapshot-based architecture. Ideal for large databases that need fast scaling.

**CosmosDB Consistency Levels (exam favorite):**

| Level | Guarantee | Latency | Multi-region Writes |
|-------|-----------|---------|-------------------|
| **Strong** | Linearizable reads | Highest | ❌ Single-region only |
| **Bounded Staleness** | Reads lag ≤ K versions or T time | High | ❌ Single-region only |
| **Session** (default) | Consistent within a client session | Medium | ✅ |
| **Consistent Prefix** | No out-of-order reads | Low | ✅ |
| **Eventual** | No ordering guarantee | Lowest | ✅ |

> 💡 **Exam Tip:** Session consistency is the default and most commonly recommended — it provides per-client consistency with good performance. Strong consistency sacrifices performance and prevents multi-region writes.

**CosmosDB APIs:** SQL (NoSQL), MongoDB, Cassandra, Gremlin (graph), Table — choose based on existing application data model and query patterns.

**CosmosDB Partitioning:** Choose partition key wisely — high cardinality, even distribution, frequently used in queries. A bad partition key creates hot partitions and throttling.

**Database Security:**
- **TDE (Transparent Data Encryption):** Enabled by default — encrypts data at rest
- **Always Encrypted:** Client-side encryption, database never sees plaintext
- **Dynamic Data Masking:** Obfuscates sensitive data for non-privileged users
- **Auditing:** Track database events to storage account or Log Analytics

**Geo-replication:**
- **Active geo-replication** (SQL DB): Up to 4 readable secondaries in any region
- **Auto-failover groups:** Automatic failover with read-write/read-only listener endpoints — recommended over manual geo-replication

**Cram Session Reference:** 1:44:30–2:03:08 (SQL-based solutions, Tables, CosmosDB)

### Deploy

```bash
cd modules/07-databases
cp terraform.tfvars.example terraform.tfvars
terraform init && terraform plan && terraform apply
```

### Explore & Verify

**In the Azure Portal:**
1. Navigate to **SQL Server** → **SQL databases** → compare the Basic (DTU) and Serverless (vCore) databases
2. Click the Serverless DB → **Compute + storage** → observe auto-pause settings and vCore range
3. Navigate to **SQL elastic pools** → inspect eDTU allocation
4. Navigate to **Azure Cosmos DB** → **Settings** → **Default consistency** → note Session level
5. Navigate to the CosmosDB container → **Scale & Settings** → inspect partition key and throughput

**Design Scenario Exercise:**
A SaaS company has 200 tenant databases, each 1–5 GB, with variable workloads peaking at different times. Which SQL deployment model and purchasing model would you recommend? What about the company's analytics database at 2TB with predictable high performance needs?

### Key Takeaways

- SQL Database for new apps, MI for migration, VM for full compatibility
- Elastic Pool for multi-tenant with variable workloads (shared resources)
- Serverless auto-pauses = significant cost savings for dev/test
- CosmosDB Session consistency = best balance (default for a reason)
- Partition key selection is critical — high cardinality, even distribution, used in queries

---

## Module 08: Data Integration

### Learning Objectives

- Design data integration pipelines using Azure Data Factory
- Understand Data Lake Gen2 architecture and the medallion pattern
- Compare ETL vs ELT approaches for cloud data processing

### Exam Relevance

**Domain:** Design data storage solutions (20–25%)
**Skills measured:** Recommend a solution for data integration, recommend a solution for data analysis

### Concepts Overview

**Azure Data Factory** is the cloud ETL/ELT service. Key components:
- **Pipelines:** Orchestration workflows containing activities
- **Activities:** Individual operations (Copy, Data Flow, Stored Procedure, Web, etc.)
- **Linked Services:** Connection definitions to data stores
- **Integration Runtime:** Compute for running activities (Azure, Self-hosted, Azure-SSIS)

> 💡 **Exam Tip:** Use **Self-hosted Integration Runtime** when Data Factory needs to access on-premises data sources or data behind a private network. This is the most common solution for hybrid data movement.

**ETL vs ELT:**
- **ETL** (Extract-Transform-Load): Transform before loading. Traditional approach.
- **ELT** (Extract-Load-Transform): Load raw, then transform in place. **Preferred in cloud** — leverage scalable cloud compute at the destination.

**Medallion Architecture:** Bronze (raw/landing) → Silver (cleaned/enriched) → Gold (business-ready/aggregated)

**Azure Synapse Analytics** = Data Factory + Apache Spark + SQL Pools + Power BI integration. It's the "unified analytics platform" — understand when to recommend it vs standalone ADF.

**Azure Databricks:** Apache Spark-based analytics platform for advanced data engineering and machine learning. Mention-worthy for exam but not deployed in this lab.

**Data Governance:** Microsoft Purview provides a unified data catalog, automated classification, and data lineage tracking across your entire data estate.

**Cram Session Reference:** 2:03:08–2:12:23 (Azure Data Factory, Data Lake)

### Deploy

```bash
cd modules/08-data-integration
cp terraform.tfvars.example terraform.tfvars
terraform init && terraform plan && terraform apply
```

### Explore & Verify

**In the Azure Portal:**
1. Navigate to **Data Factory** → **Author & Monitor** → explore the pipeline visually
2. Inspect the Linked Service → verify managed identity authentication
3. Navigate to the Data Lake storage account → **Containers** → see `raw`, `processed`, `curated` containers
4. Navigate to **Event Grid** → see the system topic on the Data Lake account

### Key Takeaways

- ELT preferred in cloud (cheaper compute, scalable)
- Self-hosted IR for on-premises data access
- Data Lake Gen2 = storage account + hierarchical namespace (POSIX ACLs)
- Medallion architecture: Bronze → Silver → Gold
- Synapse = ADF + Spark + SQL pools (recommend for unified analytics)

---

## Module 09: Compute Solutions

### Learning Objectives

- Apply the Azure compute decision tree to select the right service
- Compare App Service tiers and their feature boundaries
- Design container-based solutions (ACI vs AKS vs App Service)
- Understand serverless options (Functions hosting plans)

### Exam Relevance

**Domain:** Design infrastructure solutions (30–35%)
**Skills measured:** Specify components of a compute solution based on workload requirements

### Concepts Overview

**Compute Decision Tree (CRITICAL exam topic):**

| Service | Model | Best For | Scaling |
|---------|-------|----------|---------|
| **VMs** | IaaS | Full control, lift-and-shift, custom software | VMSS, manual |
| **App Service** | PaaS | Web apps, APIs, managed platform | Auto-scale rules |
| **ACI** | Serverless containers | Quick burst, sidecar, batch | Per-container |
| **AKS** | Orchestrated containers | Microservices, complex workloads | Node pools, HPA |
| **Functions** | Serverless | Event-driven, short tasks | Automatic (Consumption) |
| **Batch** | Managed HPC | Large-scale parallel processing | Pool-based |

**VM Families (know these for sizing questions):**
- **B-series:** Burstable, dev/test, variable workloads
- **D-series:** General purpose, balanced CPU/memory
- **E-series:** Memory-optimized, in-memory databases
- **F-series:** Compute-optimized, batch processing
- **N-series:** GPU-enabled, ML training, rendering
- **L-series:** Storage-optimized, large local disk throughput

**App Service Tier Boundaries:**

| Feature | Free/Shared | Basic | Standard | Premium | Isolated (ASE) |
|---------|------------|-------|----------|---------|----------------|
| Custom domains | Shared only | ✅ | ✅ | ✅ | ✅ |
| Deployment slots | ❌ | ❌ | ✅ (5) | ✅ (20) | ✅ (20) |
| VNet integration | ❌ | ❌ | ✅ | ✅ | Full isolation |
| Auto-scale | ❌ | ❌ | ✅ | ✅ | ✅ |

> 💡 **Exam Tip:** Deployment slots require **Standard tier or higher**. VNet integration requires **Standard or higher**. If the question mentions blue-green deployments or VNet access, the answer is at least Standard.

**Functions Hosting Plans:**
- **Consumption:** Auto-scale to zero, 5-min timeout (10 max), cold start, cheapest
- **Premium:** Pre-warmed instances, VNet integration, unlimited duration
- **Dedicated:** Runs on App Service plan, predictable costs

**Cram Session Reference:** 2:12:23–2:27:15 (Infrastructure, compute options)

### Deploy

```bash
cd modules/09-compute
cp terraform.tfvars.example terraform.tfvars
terraform init && terraform plan && terraform apply
```

### Explore & Verify

**In the Azure Portal:**
1. Navigate to the **VM** → inspect size, disk, networking, auto-shutdown configuration
2. Navigate to the **App Service** → **Configuration** → review app settings and general settings
3. Navigate to **Container Instances** → verify the nginx container is running → copy the public IP and browse to it
4. Navigate to the **Function App** → **Functions** → inspect triggers and configuration
5. Navigate to **Container Registry** → review repositories and access keys

**Design Scenario Exercise:**
Application has 10 req/sec baseline, spikes to 10,000 req/sec during sales events, and processes nightly batch reports. Choose the compute service for each component and justify your selection.

### Key Takeaways

- Match workload to service: don't use VMs when App Service suffices, don't use AKS when ACI is enough
- App Service Standard+ for deployment slots and VNet integration
- Functions Consumption for cost-sensitive event-driven; Premium for VNet and long-running
- ACI for simple containers; AKS for orchestrated microservices
- VM VMSS for legacy lift-and-shift that needs IaaS

---

## Module 10: Application Architecture

### Learning Objectives

- Select the right messaging service for different communication patterns
- Design API management solutions
- Implement caching strategies

### Exam Relevance

**Domain:** Design infrastructure solutions (30–35%)
**Skills measured:** Recommend a messaging architecture, recommend an event-driven architecture, recommend a solution for API integration, recommend a caching solution

### Concepts Overview

**Messaging Service Comparison (CRITICAL exam topic):**

| Service | Model | Delivery | Max Throughput | Best For |
|---------|-------|----------|---------------|----------|
| **Event Grid** | Push (reactive) | At-least-once | 10M events/sec | React to Azure events, webhooks |
| **Event Hubs** | Pull (streaming) | At-least-once | Millions/sec | Telemetry, IoT, Kafka workloads |
| **Service Bus** | Pull (enterprise) | At-least-once or exactly-once | Thousands/sec | Business transactions, ordering, sessions |
| **Storage Queue** | Pull (simple) | At-least-once | Thousands/sec | Simple async, >80 GB queue size |

> 💡 **Exam Tip:** The exam loves this comparison. Remember: **Event Grid** = reactive (something happened, notify subscribers), **Event Hubs** = streaming (high-volume telemetry ingestion), **Service Bus** = transactional (ordered, guaranteed, exactly-once).

**API Management Tiers:**
- **Consumption:** Serverless, per-call pricing, no infrastructure cost. Best for low-volume labs.
- **Developer:** Non-production, includes developer portal.
- **Standard/Premium:** Production. Premium adds multi-region, VNet, 99.99% SLA.

**Caching Pattern (Cache-Aside):**
1. App checks Redis cache for data
2. Cache miss → read from database → store in cache → return
3. Cache hit → return directly (fast!)

**Cram Session Reference:** 2:27:15–2:35:00 (Component communication, API Management)

### Deploy

```bash
cd modules/10-app-architecture
cp terraform.tfvars.example terraform.tfvars
terraform init && terraform plan && terraform apply
```

### Explore & Verify

**In the Azure Portal:**
1. Navigate to **Event Grid Topics** → inspect the topic endpoint and subscriptions
2. Navigate to **Event Hubs** → inspect the namespace, event hub, consumer groups, throughput settings
3. Navigate to **Service Bus** → inspect queues (dead-letter settings) and topics (subscriptions)
4. Navigate to **API Management** → explore the developer portal and API definitions
5. Navigate to **Azure Cache for Redis** → check connection info, memory usage, tier

**Design Scenario Exercise:**
An e-commerce platform needs: (1) order processing with guaranteed delivery and ordering, (2) real-time inventory notifications to 50 microservices, (3) IoT telemetry from 100K devices at 1M events/sec. Select the appropriate messaging service for each and justify.

### Key Takeaways

- Event Grid for reactive, Event Hubs for streaming, Service Bus for transactional
- Storage Queue for simple scenarios (>80 GB queue or >64 KB messages)
- APIM Consumption tier for serverless API gateway
- Cache-aside is the most common caching pattern
- Redis Basic for dev/test; Standard for production (replication)

**Azure App Configuration:** Centralized configuration management with feature flags — enables dynamic configuration updates and staged feature rollouts without redeployment.

---

## Module 11: Networking

### Learning Objectives

- Design hub-and-spoke network topology
- Compare VPN Gateway vs ExpressRoute
- Implement network security with NSGs, Azure Firewall, and private endpoints
- Understand DNS resolution in Azure

### Exam Relevance

**Domain:** Design infrastructure solutions (30–35%)
**Skills measured:** Recommend a connectivity solution, recommend a solution to optimize network performance/security, recommend a load-balancing and routing solution

### Concepts Overview

**Hub-and-Spoke Topology (exam favorite):**
- **Hub VNet:** Shared services — firewall, VPN gateway, DNS, monitoring
- **Spoke VNets:** Workload isolation, peered to hub
- **Key fact:** VNet peering is **non-transitive**. Spoke A cannot talk to Spoke B through the hub unless traffic routes through a firewall/NVA in the hub.

**Connectivity to On-Premises:**

| Method | Connection | Bandwidth | Latency | Use Case |
|--------|-----------|-----------|---------|----------|
| **VPN Gateway** | Encrypted over internet | Up to 10 Gbps | Variable | Cost-effective, moderate bandwidth |
| **ExpressRoute** | Private via provider | 50 Mbps–100 Gbps | Consistent, low | High bandwidth, compliance |
| **ExpressRoute + VPN** | Both | Combined | Best of both | ExpressRoute primary, VPN failover |

> ⚠️ **Common Mistake:** VNet peering is non-transitive. If VNet A is peered with VNet B, and VNet B is peered with VNet C, VNet A CANNOT communicate with VNet C unless you configure routing through B (via NVA/firewall).

**Security Comparison:**
- **NSG:** Layer 3/4, per-subnet or per-NIC, stateful rules, free
- **Azure Firewall:** Layer 3–7, centralized, FQDN filtering, threat intelligence, $912/month
- **ASG (Application Security Groups):** Logical grouping of VMs — use in NSG rules instead of IP addresses for cleaner, scalable security rules
- **Private Endpoint:** Private IP for PaaS services, eliminates public exposure

> 💡 **Exam Tip:** Private Link (private endpoint) is the recommended way to access PaaS services from a VNet. Service endpoints optimize routing but the service still has a public IP. Private endpoints give the service a private IP in your VNet.

**Azure DNS:**
- **Public DNS zones:** Host your domain's DNS records in Azure (high availability, fast resolution)
- **Private DNS zones:** Name resolution within VNets — link zones to VNets for automatic registration
- **Private DNS Resolver:** Enables conditional forwarding between Azure and on-premises DNS — replaces the need for custom DNS VMs

**Cram Session Reference:** 2:35:00–2:43:49 (Networking core concepts)

### Deploy

```bash
cd modules/11-networking
cp terraform.tfvars.example terraform.tfvars
terraform init && terraform plan && terraform apply
```

### Explore & Verify

**In the Azure Portal:**
1. Navigate to **Virtual Networks** → find the secondary VNet → **Peerings** → verify bidirectional peering status is "Connected"
2. Navigate to **Network Security Groups** → inspect inbound/outbound rules and priority ordering
3. Navigate to **Route Tables** → inspect custom routes and associated subnets
4. Navigate to **Private DNS Zones** → verify zone is linked to VNets and records resolve correctly
5. Try: **Network Watcher** → **Connection troubleshoot** to test connectivity between resources

**Design Scenario Exercise:**
An enterprise with 5 workloads needs: (1) centralized internet egress with FQDN filtering, (2) private connectivity to on-premises at 10 Gbps with <10ms latency, (3) workload isolation between departments. Design the complete network architecture.

### Key Takeaways

- VNet peering is non-transitive — critical for hub-spoke routing design
- Hub-spoke = centralized security (firewall in hub) + workload isolation (spokes)
- ExpressRoute for high bandwidth + low latency + compliance; VPN for cost-effective
- Private endpoint > service endpoint for PaaS security
- NSG = free, per-subnet; Firewall = centralized L7 filtering, expensive

---

## Module 12: Migration

### Learning Objectives

- Apply the Cloud Adoption Framework migration methodology
- Classify workloads using the 5 Rs migration strategies
- Select appropriate Azure migration tools for different workload types

### Exam Relevance

**Domain:** Design infrastructure solutions (30–35%)
**Skills measured:** Evaluate a migration solution leveraging CAF, recommend a solution for migrating workloads to IaaS/PaaS

### Concepts Overview

**Cloud Adoption Framework (CAF):** Strategy → Plan → Ready → **Migrate** → Innovate → Govern → Manage

**5 Rs of Migration (CRITICAL exam topic):**

| Strategy | Changes | Target | Speed | Cost |
|----------|---------|--------|-------|------|
| **Rehost** (lift-and-shift) | Minimal | IaaS (VMs) | Fastest | Lowest initial |
| **Refactor** | Minor code changes | PaaS | Moderate | Moderate |
| **Rearchitect** | Significant redesign | Cloud-native | Slow | Higher initial |
| **Rebuild** | Complete rewrite | Cloud-native | Slowest | Highest initial |
| **Replace** | Adopt SaaS | SaaS | Fast | Varies |

**Migration Tools:**
| Tool | Use Case |
|------|----------|
| **Azure Migrate** | Discovery, assessment, server migration (agentless/agent-based) |
| **Azure Site Recovery** | VM replication to Azure, test failover, minimal downtime cutover |
| **Database Migration Service** | SQL, MySQL, PostgreSQL, MongoDB → Azure databases (online/offline) |
| **Data Box** | Physical device for large data transfer (>40 TB offline) |

> 💡 **Exam Tip:** DMS **online migration** provides continuous sync with minimal downtime. **Offline migration** requires application downtime during data transfer. Always recommend online for production workloads.

**Cram Session Reference:** 2:43:49–2:49:50 (Migration)

### Deploy

```bash
cd modules/12-migration
cp terraform.tfvars.example terraform.tfvars
terraform init && terraform plan && terraform apply
```

### Explore & Verify

**In the Azure Portal:**
1. Navigate to **Azure Migrate** → explore the project → review assessment capabilities
2. Navigate to the **Recovery Services Vault** → understand replication settings
3. Navigate to the **Database Migration Service** → review supported source/target pairs
4. SSH to the simulated on-premises VM → inspect the running web server

**Design Scenario Exercise:**
Company has: 5 SQL Servers (2 with CLR assemblies), 20 IIS web servers, 10 file servers (50 TB total), 3 legacy apps with hardcoded IP addresses. For each workload, recommend the migration strategy (which R), target Azure service, and migration tool.

### Key Takeaways

- Know the 5 Rs and when to apply each
- Azure Migrate for discovery + assessment, ASR for VM migration, DMS for databases
- DMS online = minimal downtime, offline = simpler but requires downtime
- Data Box for >40 TB offline transfer
- SQL MI for near-100% compatibility (lift-and-shift of SQL Server)

---

## Module 13: Well-Architected Framework Review 🔴

> This is a conceptual review module — no resources to deploy. Study these concepts carefully as WAF principles appear throughout the exam.

**Five Pillars** (Cram Session: 2:49:50–3:36:40):

### Cost Optimization
- Right-size resources (Azure Advisor recommendations)
- Reserved Instances (1 or 3 year) for predictable workloads
- Spot VMs for interruptible workloads (up to 90% savings)
- Auto-scaling to match demand
- Azure Cost Management + Budgets for visibility

### Operational Excellence
- Infrastructure as Code (Terraform, Bicep, ARM)
- CI/CD pipelines for automated deployments
- Blue-green and canary deployment strategies
- Monitoring and alerting (Azure Monitor)
- Runbooks for automated remediation

### Performance Efficiency
- Vertical scaling (bigger VMs) vs horizontal scaling (more instances)
- Caching (Redis, CDN) to reduce backend load
- Async processing (queues, events) to decouple components
- Database optimization (indexing, partitioning, read replicas)

### Reliability
- Availability zones and regions for redundancy
- Health modeling and self-healing architecture
- Circuit breaker pattern for dependent services
- Chaos engineering to test failure modes
- Backup and DR with defined RPO/RTO

### Security
- Zero Trust: verify explicitly, least privilege, assume breach
- Defense in depth: network → identity → application → data
- Encryption at rest and in transit
- Key Vault for secrets management
- Microsoft Defender for Cloud for posture management

---

## Comprehensive Review

### What You've Built

Across 13 modules, you deployed approximately **60+ Azure resources** spanning all four AZ-305 exam domains:
- Identity/Governance: Management groups, policies, RBAC roles, Entra ID groups, Key Vault, monitoring alerts
- Data Storage: 3 storage accounts, SQL databases, CosmosDB, Data Factory, Data Lake
- Business Continuity: Availability sets/zones, load balancers, Recovery Services Vault, Traffic Manager
- Infrastructure: VMs, App Service, containers, functions, messaging services, VNet peering, NSGs

### What You've Learned

**Design identity, governance, and monitoring solutions (25–30%)**
- Governance hierarchy design: management groups → subscriptions → resource groups
- Azure Policy lifecycle: definition → assignment → evaluation → remediation
- RBAC with least privilege and custom role definitions
- Identity sync methods: PHS vs PTA vs Federation and when each applies
- Conditional Access policy design for Zero Trust
- Key Vault access models: vault access policies vs RBAC
- Monitoring architecture: Log Analytics workspace topology, alert rules, action groups

**Design data storage solutions (20–25%)**
- Storage account types, replication options (LRS→RA-GZRS), and access tiers
- Lifecycle management for cost optimization across Hot/Cool/Cold/Archive
- SQL deployment model decision tree: DB vs Elastic Pool vs MI vs VM
- DTU vs vCore purchasing models and when to use Serverless
- CosmosDB consistency levels and partitioning strategy
- Data integration with ADF, medallion architecture, ELT patterns

**Design business continuity solutions (15–20%)**
- Composite SLA calculation for multi-tier architectures
- Availability Sets (99.95%) vs Availability Zones (99.99%)
- Backup strategy design with RPO/RTO requirements
- Load balancer selection: Azure LB vs App Gateway vs Front Door vs Traffic Manager

**Design infrastructure solutions (30–35%)**
- Compute decision tree: VMs → App Service → ACI → AKS → Functions → Batch
- Messaging service selection: Event Grid vs Event Hubs vs Service Bus
- Hub-and-spoke network design with centralized security
- VPN vs ExpressRoute connectivity patterns
- Migration strategy using the 5 Rs and Azure Migrate/ASR/DMS tooling

### Exam Readiness Checklist

**Design identity, governance, and monitoring solutions (25–30%)**
- [ ] Can I design a management group hierarchy for an enterprise?
- [ ] Can I select the right policy effect (Audit vs Deny vs DeployIfNotExists)?
- [ ] Can I recommend PHS vs PTA vs Federation for a given scenario?
- [ ] Can I design a Conditional Access policy?
- [ ] Can I choose between Key Vault access policies and RBAC?
- [ ] Can I design a monitoring solution with appropriate workspace topology?

**Design data storage solutions (20–25%)**
- [ ] Can I select the right storage replication option for a given durability/availability requirement?
- [ ] Can I design a lifecycle management policy?
- [ ] Can I choose between SQL Database, Elastic Pool, Managed Instance, and SQL VM?
- [ ] Can I select the right CosmosDB consistency level?
- [ ] Can I design a data integration architecture (ADF, Data Lake, medallion)?

**Design business continuity solutions (15–20%)**
- [ ] Can I calculate the SLA for a multi-tier architecture?
- [ ] Can I select the right availability option (set vs zone)?
- [ ] Can I design a backup strategy with appropriate RPO/RTO?
- [ ] Can I select the right load balancer for a given scenario?

**Design infrastructure solutions (30–35%)**
- [ ] Can I apply the compute decision tree to select the right service?
- [ ] Can I select the right messaging service (Event Grid vs Hubs vs Service Bus)?
- [ ] Can I design a hub-spoke network topology?
- [ ] Can I recommend VPN vs ExpressRoute?
- [ ] Can I classify workloads using the 5 Rs and select migration tools?

### Practice Questions

**1.** Your organization needs to ensure all VMs in production subscriptions use only approved SKU sizes. Which Azure service and feature would you implement?

<details><summary>Answer</summary>
Azure Policy with a "Deny" effect and the built-in "Allowed virtual machine size SKUs" policy, assigned at the management group or subscription level containing production subscriptions.
</details>

**2.** A company has 500 users on-premises using Active Directory. They need SSO to Azure resources and want to detect leaked credentials. Which sync method do you recommend?

<details><summary>Answer</summary>
Password Hash Synchronization (PHS) with Seamless SSO. PHS is required for Azure AD Identity Protection to detect leaked credentials. Seamless SSO provides transparent authentication from domain-joined devices.
</details>

**3.** An application requires 99.99% SLA. The web tier runs on 2 VMs with a Standard Load Balancer. What availability option is required?

<details><summary>Answer</summary>
Availability Zones. Availability Sets provide 99.95% SLA; only Availability Zones provide 99.99% SLA. The VMs must be placed in different zones with a Standard Load Balancer (which is zone-redundant by default).
</details>

**4.** You need to store 100 TB of data that's accessed daily for 30 days, then rarely for 1 year, then must be retained for 7 years for compliance. Design the storage solution.

<details><summary>Answer</summary>
GPv2 storage account with GRS replication (compliance requires geo-redundancy). Lifecycle management policy: Hot tier for first 30 days → Cool for days 30–365 → Archive after 365 days. Archive ensures lowest cost for long-term compliance retention. Consider immutable storage with a legal hold or time-based retention policy.
</details>

**5.** A SaaS application has 200 tenant databases, each 1–5 GB with variable workloads that peak at different times. Which Azure SQL deployment model?

<details><summary>Answer</summary>
Azure SQL Elastic Pool. Elastic pools share compute resources across multiple databases, so when tenants peak at different times, they share the DTU/vCore capacity efficiently. This is significantly more cost-effective than provisioning individual databases at peak capacity.
</details>

**6.** Your e-commerce platform needs: order processing with guaranteed delivery and ordering, inventory change notifications to 50 microservices, and IoT telemetry from 100K devices. Select messaging services.

<details><summary>Answer</summary>
Order processing: Azure Service Bus (guaranteed delivery, ordering via sessions, exactly-once with deduplication). Inventory notifications: Azure Event Grid (push-based fan-out to 50 subscribers, reactive to events). IoT telemetry: Azure Event Hubs (millions/sec throughput, partitioned consumers, Kafka-compatible).
</details>

**7.** A company has 20 on-premises SQL Servers, some using SQL Agent jobs and cross-database queries. They want minimal code changes during migration. Which target and tool?

<details><summary>Answer</summary>
Azure SQL Managed Instance (MI) — it provides near-100% SQL Server compatibility including SQL Agent, cross-database queries, CLR, and linked servers. Use Database Migration Service (DMS) in online mode for minimal downtime migration.
</details>

**8.** An enterprise needs private connectivity from on-premises to Azure with consistent <5ms latency and 10 Gbps bandwidth. What connectivity solution?

<details><summary>Answer</summary>
Azure ExpressRoute with a 10 Gbps circuit. ExpressRoute provides private connectivity through a service provider with consistent low latency (unlike VPN over internet). Consider ExpressRoute with VPN failover for redundancy.
</details>

**9.** A startup wants to run a containerized API that handles 10 requests/hour normally but 10,000 during product launches. They don't want to manage infrastructure. Which compute service?

<details><summary>Answer</summary>
Azure Container Instances (ACI) for the simple API container with serverless scaling, or Azure Functions (Consumption plan) if the API can be refactored to event-driven. ACI is best for containerized workloads without orchestration needs. AKS would be overkill for a single service.
</details>

**10.** Your application stores session state that must be accessible by all web servers with sub-millisecond latency. The data is ephemeral (losing it is acceptable). What solution?

<details><summary>Answer</summary>
Azure Cache for Redis (Standard tier for production with replication). The cache-aside pattern stores session state with sub-millisecond reads. Standard tier provides SLA and replication. Since data is ephemeral, persistence isn't required.
</details>

**11.** A financial services company needs a CosmosDB database for trading records that must always return the absolute latest data, even at the cost of performance. Which consistency level and what limitation applies?

<details><summary>Answer</summary>
Strong consistency — provides linearizable reads guaranteeing the latest committed write is always returned. The limitation: Strong consistency is only available with single-region writes. Multi-region write configurations cannot use Strong consistency.
</details>

**12.** An organization has 3 Azure subscriptions: Production, Development, and Sandbox. They want to enforce tag requirements on Production only, restrict VM sizes on Production and Development, and allow anything in Sandbox. How would you structure governance?

<details><summary>Answer</summary>
Create a management group hierarchy: Root MG → (Production MG, Non-Production MG → Dev, Sandbox). Assign the "Require CostCenter Tag" policy with Deny effect at the Production MG. Assign "Allowed VM SKUs" policy at the Root MG with an exemption for the Sandbox subscription. This applies governance at the right scope without duplicating assignments.
</details>

**13.** A company needs to migrate 80 TB of historical data from on-premises to Azure Blob Storage. Their internet bandwidth is 1 Gbps. What's the most practical migration approach?

<details><summary>Answer</summary>
Azure Data Box. At 1 Gbps, transferring 80 TB would take approximately 8 days of sustained transfer (assuming 100% utilization). Data Box is recommended for transfers >40 TB and can ship within days. It's more reliable than network transfer for large datasets.
</details>

**14.** You're designing a multi-region web application. The frontend should route users to the nearest region, and the database backend needs automatic failover. Which services do you recommend?

<details><summary>Answer</summary>
Azure Front Door for global HTTP load balancing with anycast (routes users to nearest region based on latency). Azure SQL with auto-failover groups for the database (provides read-write and read-only listener endpoints with automatic DNS-based failover). Front Door also provides WAF, SSL termination, and caching.
</details>

**15.** An application team wants to deploy a new feature to 10% of users first, then gradually increase to 100%. They're using App Service. What features do they need?

<details><summary>Answer</summary>
App Service deployment slots (requires Standard tier or higher) with traffic routing. Deploy the new version to a staging slot, then use traffic routing to send 10% of production traffic to the staging slot. Gradually increase the percentage. When confident, perform a full slot swap. Optionally, use Azure App Configuration feature flags for more granular control.
</details>

**16.** Your organization runs a critical application across two Azure regions. If the primary region fails, the application must be running in the secondary region within 15 minutes (RTO) with no more than 5 minutes of data loss (RPO). Design the DR solution.

<details><summary>Answer</summary>
Use Azure Site Recovery (ASR) for VM replication with continuous replication (meets 5-min RPO). Configure recovery plans with automated steps for ordered failover. For databases, use Azure SQL auto-failover groups with asynchronous replication (RPO ≈ 5 seconds). Run regular DR drills using ASR's test failover feature (doesn't impact production). Monitor with Azure Monitor alerts on replication health.
</details>

**17.** A web application receives 500 events/second from IoT devices AND needs to process customer orders with exactly-once delivery. Should you use one messaging service or two? Which ones?

<details><summary>Answer</summary>
Two separate services: Azure Event Hubs for IoT telemetry ingestion (designed for millions of events/sec, partitioned streaming, Kafka-compatible) and Azure Service Bus for order processing (supports exactly-once delivery via duplicate detection, message sessions for ordering, and dead-letter queues for failed processing). Using one service for both would compromise on key guarantees.
</details>

**18.** (Multi-select) Which THREE of the following require Azure App Service Standard tier or higher? A) Custom domains B) Deployment slots C) VNet integration D) Auto-scale E) Always On

<details><summary>Answer</summary>
B, C, D — Deployment slots, VNet integration, and auto-scale all require Standard tier or higher. Custom domains (A) are available from Basic tier. Always On (E) is available from Basic tier. This is a frequently tested boundary on the exam.
</details>

### Knowledge Gaps & Additional Study

Topics that couldn't be fully covered in the lab (due to cost, complexity, or requiring production environments):

| Topic | Why Not Covered | Recommended Study |
|-------|----------------|-------------------|
| **ExpressRoute** | Requires physical provider relationship | [MS Learn: ExpressRoute](https://learn.microsoft.com/en-us/azure/expressroute/expressroute-introduction) |
| **Full AKS cluster** | Complex, costly, beyond single-module scope | [MS Learn: AKS](https://learn.microsoft.com/en-us/azure/aks/intro-kubernetes) |
| **Azure Firewall Premium** | ~$912/month, TLS inspection requires certs | [MS Learn: Azure Firewall](https://learn.microsoft.com/en-us/azure/firewall/overview) |
| **SQL Managed Instance** | 4+ hour provisioning, ~$100/month minimum | [MS Learn: SQL MI](https://learn.microsoft.com/en-us/azure/azure-sql/managed-instance/sql-managed-instance-paas-overview) |
| **Azure AD B2C / B2B** | Requires separate tenant configuration | [MS Learn: External Identities](https://learn.microsoft.com/en-us/azure/active-directory/external-identities/) |
| **Azure Synapse Analytics** | Complex multi-service deployment | [MS Learn: Synapse](https://learn.microsoft.com/en-us/azure/synapse-analytics/overview-what-is) |
| **Azure Virtual WAN** | Enterprise-only, expensive | [MS Learn: Virtual WAN](https://learn.microsoft.com/en-us/azure/virtual-wan/virtual-wan-about) |
| **Microsoft Purview** | Complex data governance platform | [MS Learn: Purview](https://learn.microsoft.com/en-us/purview/purview) |
| **Azure Bastion** | ~$140/month for Basic SKU | [MS Learn: Bastion](https://learn.microsoft.com/en-us/azure/bastion/bastion-overview) |
| **Chaos engineering** | Requires production-like workloads | [MS Learn: Azure Chaos Studio](https://learn.microsoft.com/en-us/azure/chaos-studio/chaos-studio-overview) |

**Recommended Microsoft Learn Paths:**
- [AZ-305: Design identity, governance, and monitoring](https://learn.microsoft.com/en-us/training/paths/design-identity-governance-monitor-solutions/)
- [AZ-305: Design data storage solutions](https://learn.microsoft.com/en-us/training/paths/design-data-storage-solutions/)
- [AZ-305: Design business continuity solutions](https://learn.microsoft.com/en-us/training/paths/design-business-continuity-solutions/)
- [AZ-305: Design infrastructure solutions](https://learn.microsoft.com/en-us/training/paths/design-infra-solutions/)

### Official Microsoft Resources

- [AZ-305 Study Guide](https://learn.microsoft.com/en-us/credentials/certifications/resources/study-guides/az-305)
- [Free Practice Assessment](https://learn.microsoft.com/en-us/credentials/certifications/exams/az-305/practice/assessment?assessment-type=practice&assessmentId=15)
- [Exam Registration](https://learn.microsoft.com/en-us/credentials/certifications/exams/az-305/)
- [Exam Sandbox](https://aka.ms/examdemo)
- [Azure Solutions Architect Certification](https://learn.microsoft.com/en-us/credentials/certifications/azure-solutions-architect/)
- [John Savill's AZ-305 Cram Video](https://www.youtube.com/watch?v=vq9LuCM4YP4)
- [John Savill's AZ-305 Study Playlist](https://youtube.com/playlist?list=PLlVtbbG169nHSnaP4ae33yQUI3zcmP5nP)
- [OnBoard to Azure](https://learn.onboardtoazure.com)
- [Certification Materials Repo](https://github.com/johnthebrit/CertificationMaterials)
- [WAF Documentation](https://learn.microsoft.com/en-us/azure/architecture/framework/)
- [Azure Architecture Center](https://learn.microsoft.com/en-us/azure/architecture/)

### Next Steps

1. **Take the free practice assessment** — link above, tests actual exam format
2. **Try the exam sandbox** — get comfortable with the exam interface
3. **Review weak areas** — re-deploy specific modules and redo exercises
4. **Schedule the exam** — set a date to create accountability
5. **Final review** — re-read the Key Takeaways from each module the day before
6. **On exam day:** Eliminate obviously wrong answers, think "how would I architect this?", and don't overthink — Azure services are named logically

---

*Generated by CertForge v1.1 — Based on John Savill's AZ-305 Study Cram*
