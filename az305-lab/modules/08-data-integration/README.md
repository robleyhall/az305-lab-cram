# Module 08 — Data Integration

Azure Data Factory + Data Lake Gen2 lab for AZ-305 data integration topics.

## AZ-305 Exam Domain

**15–20% of exam weight** — Design data storage solutions, design data integration solutions.

This module covers how to move, transform, and organize data at scale in Azure — one of the most heavily tested areas on AZ-305. You need to know when to use Data Factory vs Synapse vs Databricks, how Data Lake Gen2 differs from Blob Storage, and how to secure analytical data stores.

## What This Module Creates

| Resource | Type | Purpose |
|----------|------|---------|
| Resource Group | `az305-lab-dataintegration-rg` | Holds all data integration resources |
| Azure Data Factory | `az305-lab-adf-{suffix}` | ETL/ELT orchestration engine |
| ADF Linked Service | `ls-datalake` | Managed identity connection to Data Lake |
| ADF Pipeline | `sample-copy-pipeline` | Demonstrates pipeline/activity pattern |
| Data Lake Gen2 | `az305-labdl{suffix}` | Hierarchical storage with POSIX ACLs |
| ADLS Containers | `raw`, `processed`, `curated` | Medallion architecture layers |
| Event Grid System Topic | `az305-lab-datalake-events-{suffix}` | Event-driven data processing trigger |
| RBAC Assignment | Storage Blob Data Contributor | ADF identity → Data Lake access |
| Diagnostic Settings | ADF + Data Lake + Event Grid | Logs/metrics → Log Analytics |

## Estimated Cost

**~$1/day** — Data Factory at rest costs nothing (pay per pipeline run). Data Lake Standard LRS is ~$0.018/GB/month. Event Grid System Topic is free; events are $0.60/million. The only meaningful cost comes from actually running pipelines.

## Prerequisites

- Terraform >= 1.5.0
- Azure CLI authenticated (`az login`)
- Module 00 (foundation) deployed — provides VNet, subnet, Log Analytics workspace
- `Microsoft.EventGrid` resource provider registered on the subscription

## Deploy

```bash
cd az305-lab/modules/08-data-integration

# Copy and edit variables
cp terraform.tfvars.example terraform.tfvars
# Fill in values from Module 00 outputs:
#   terraform -chdir=../00-foundation output vnet_id
#   terraform -chdir=../00-foundation output log_analytics_workspace_id

terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

## Destroy

```bash
terraform destroy
# No resource locks in this module — straightforward destroy.
# If ADF has active pipeline runs, cancel them first in the portal.
```

## Key Concepts for AZ-305

### Azure Data Factory Architecture

ADF organizes data workflows into **pipelines** containing **activities** (Copy, Data Flow, Lookup, Web, etc.). **Linked Services** define connections to data stores. **Datasets** describe data shape. **Integration Runtimes** determine where compute runs:

- **Azure IR**: Serverless, auto-resolve region. Default for cloud-to-cloud.
- **Self-Hosted IR**: Agent on a VM for on-premises or private network data.
- **Azure-SSIS IR**: Runs existing SSIS packages in the cloud.

### ETL vs ELT

| Pattern | Transform Where? | Best For |
|---------|------------------|----------|
| ETL | Outside destination (ADF compute) | Small/medium data, schema-on-write |
| ELT | Inside destination (Synapse, Spark) | Large-scale analytics, schema-on-read |

**AZ-305 favors ELT** — land raw data first, then transform using the destination's compute (cheaper, more scalable).

### Medallion Architecture

```
Bronze (raw/)        → Silver (processed/)     → Gold (curated/)
Exact source copy      Cleaned, deduplicated      Business aggregates
Partitioned by date    Schema-enforced            Optimized for BI
Immutable audit trail  Joined across sources      KPIs and reports
```

### Data Lake Gen2 vs Blob Storage

| Feature | Blob Storage | Data Lake Gen2 |
|---------|-------------|----------------|
| Namespace | Flat | Hierarchical |
| Directory rename | O(n) — copies all blobs | O(1) — atomic metadata operation |
| ACLs | Container-level RBAC only | POSIX ACLs on files and directories |
| Spark/ABFSS | Limited | Native support |
| Use case | Application data | Analytics / data lake |

**Always enable hierarchical namespace for analytics workloads.**

### Synapse Analytics vs Data Factory

| Capability | Data Factory | Synapse Analytics |
|------------|-------------|-------------------|
| Pipelines | ✅ | ✅ (same engine) |
| Spark pools | ❌ | ✅ |
| SQL pools | ❌ | ✅ (dedicated + serverless) |
| Workspace | ❌ | ✅ (unified experience) |

Use standalone ADF for pure orchestration. Use Synapse when you need analytics compute co-located with pipelines.

### Data Lake Security — Defense in Depth

1. **Network**: Storage firewall, private endpoints, VNet service endpoints
2. **Identity**: Azure RBAC (Storage Blob Data Contributor/Reader)
3. **ACLs**: POSIX ACLs for fine-grained directory/file permissions
4. **Encryption**: SSE (Microsoft-managed or customer-managed keys)
5. **Governance**: Microsoft Purview for classification and lineage

### Event-Driven Data Processing

Instead of scheduled polling, use **Event Grid** to react instantly when files land in the Data Lake. Pattern: Blob created → Event Grid → ADF trigger (or Function or Logic App) → process file.

### Microsoft Purview (Not Deployed)

Unified data governance: automated scanning, classification, lineage tracking, and data catalog across Azure, on-premises, and multi-cloud sources. Essential for compliance-heavy AZ-305 scenarios.

### Azure Databricks (Not Deployed)

Managed Apache Spark for large-scale data engineering and ML. Integrates with Data Lake Gen2 via ABFSS. ADF can orchestrate Databricks notebooks as pipeline activities.

## Exercises

1. **Explore ADF Studio**: Open the Data Factory in the Azure portal → "Launch Studio". Navigate Pipelines, Linked Services, and Integration Runtimes.
2. **Run the sample pipeline**: Trigger `sample-copy-pipeline` manually and observe the run in Monitor.
3. **Browse the Data Lake**: Use Azure Storage Explorer to navigate `raw/`, `processed/`, `curated/` containers.
4. **Add a Copy activity**: Replace the Wait activity with a Copy activity that moves a CSV from `raw/` to `processed/` as Parquet.
5. **Test Event Grid**: Upload a file to `raw/` and check the Event Grid metrics for a BlobCreated event.
6. **Set ACLs**: Use `az storage fs access set` to apply POSIX ACLs on the `curated/` container, restricting access to a specific user.
7. **Compare IR types**: In ADF Studio, look at Integration Runtimes. Note the default AutoResolveIntegrationRuntime. Consider when you'd add a Self-Hosted IR.

## Architecture Diagram

```
┌─────────────────────────────────────────────────────┐
│  Azure Data Factory (Managed VNet)                  │
│  ┌───────────────┐  ┌───────────────────────────┐   │
│  │  Pipeline:     │  │  Linked Service:          │   │
│  │  Copy Activity │──│  Data Lake Gen2            │   │
│  │  Data Flow     │  │  (managed identity auth)  │   │
│  └───────────────┘  └──────────┬────────────────┘   │
│                                │                     │
│  Integration Runtimes:         │                     │
│  • Azure IR (default)          │                     │
│  • Self-Hosted IR (on-prem)    │                     │
└────────────────────────────────┼─────────────────────┘
                                 │
                    ┌────────────▼────────────┐
                    │  Data Lake Gen2          │
                    │  ┌─────┐ ┌─────┐ ┌─────┐│
                    │  │ raw │ │proc.│ │curat││
                    │  │Bronz│ │Silvr│ │Gold ││
                    │  └─────┘ └─────┘ └─────┘│
                    │  HNS + POSIX ACLs        │
                    └────────────┬─────────────┘
                                 │
                    ┌────────────▼────────────┐
                    │  Event Grid System Topic │
                    │  BlobCreated → trigger   │
                    └─────────────────────────┘
```
