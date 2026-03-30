# Module 07 — Database Solutions

Demonstrates Azure SQL Database and Azure Cosmos DB — the two most heavily
tested database services on the AZ-305 exam. SQL is mentioned 64 times in the
cram session. This module covers deployment models, purchasing models,
serverless compute, elastic pools, consistency levels, and partitioning.

## AZ-305 Exam Relevance

| Topic | Weight | What This Module Covers |
|---|---|---|
| SQL deployment models | **Critical** | Single DB, Elastic Pool (+ exam notes on Managed Instance, SQL on VM) |
| DTU vs vCore purchasing | **High** | Basic (DTU) database + General Purpose Serverless (vCore) database |
| Serverless compute tier | High | Auto-pause, auto-scale, pay-per-second billing |
| Elastic pools | High | Shared DTU pool for multi-tenant / many-database scenarios |
| Cosmos DB consistency levels | **Critical** | Session consistency (default); exam notes cover all five levels |
| Cosmos DB partitioning | High | Partition key strategy with `/category` example |
| Private endpoint connectivity | High | Private DNS + VNet Link + Endpoint for SQL Server |
| Database security | High | TDE, Always Encrypted, auditing, TLS 1.2, Azure AD auth |
| Geo-replication / failover | Medium | Exam notes on Active Geo-Rep vs Auto-Failover Groups |
| Cosmos DB APIs | Medium | Exam notes on SQL, MongoDB, Cassandra, Gremlin, Table |

## Key Concepts

### Azure SQL Deployment Models (Decision Tree)

| Model | Compatibility | Management | Best For |
|---|---|---|---|
| **SQL Database (Single)** | ~95% T-SQL | Fully managed PaaS | Cloud-native apps, single-tenant |
| **SQL Elastic Pool** | ~95% T-SQL | Fully managed PaaS | Multi-tenant SaaS, variable workloads |
| **SQL Managed Instance** | ~99% SQL Server | Managed PaaS in VNet | Lift-and-shift, cross-DB queries, SQL Agent |
| **SQL on Azure VM** | 100% SQL Server | IaaS (you manage OS) | SSIS/SSRS/SSAS, full OS control |

**Quick decision:** Need SQL Agent, CLR, or cross-DB queries → Managed Instance.
Need SSIS/SSRS → SQL on VM. Otherwise → SQL Database or Elastic Pool.

### DTU vs vCore Purchasing Models

| Aspect | DTU Model | vCore Model |
|---|---|---|
| **Scaling** | Bundled (compute + I/O + memory) | Independent (compute + storage) |
| **Tiers** | Basic / Standard / Premium | General Purpose / Business Critical / Hyperscale |
| **Serverless** | ❌ Not available | ✅ GP Serverless (auto-pause) |
| **Azure Hybrid Benefit** | ❌ | ✅ Reuse SQL Server licenses |
| **Best for** | Simple, predictable workloads | Fine-grained control, license savings |

### Cosmos DB Consistency Levels

| Level | Guarantee | Latency | Use Case |
|---|---|---|---|
| **Strong** | Linearizability (always latest) | Highest | Financial transactions |
| **Bounded Staleness** | Reads lag by ≤ K versions or T time | High | Apps needing staleness bound |
| **Session** ⭐ | Read-your-writes within session | Moderate | Most applications (default) |
| **Consistent Prefix** | Reads never see out-of-order writes | Low | Apps needing ordering |
| **Eventual** | No ordering guarantees | Lowest | Highest throughput, global apps |

⭐ Session is the default and recommended starting point. Strong consistency is
**not available** with multi-region writes.

### Cosmos DB APIs

| API | Wire Protocol | Migrate From | Notes |
|---|---|---|---|
| **SQL (NoSQL)** | Native | New apps | Most features, most tested on AZ-305 |
| MongoDB | MongoDB protocol | MongoDB | Use existing drivers/tools |
| Cassandra | Cassandra protocol | Cassandra | Global distribution for Cassandra |
| Gremlin | Apache TinkerPop | Graph databases | Social networks, recommendations |
| Table | Azure Table Storage | Table Storage | Global distribution for key-value |

> ⚠️ The API is chosen at account creation and **cannot be changed** later.

## What This Module Creates

| Resource | Name Pattern | Purpose |
|---|---|---|
| Resource Group | `az305-lab-databases-rg-<suffix>` | Container for all database resources |
| SQL Server | `az305-lab-sqlserver-<suffix>` | Azure SQL logical server with Azure AD admin |
| SQL Database (Basic) | `az305-lab-sqldb-basic` | DTU model demo (5 DTUs, 2 GB) |
| SQL Database (Serverless) | `az305-lab-sqldb-serverless` | vCore serverless demo (auto-pause at 60 min) |
| SQL Elastic Pool | `az305-lab-sql-pool-<suffix>` | Shared pool demo (BasicPool, 50 eDTUs) |
| SQL Firewall Rules | 2 rules | Allow Azure services + lab client IP |
| Private Endpoint | `az305-lab-sql-pe-<suffix>` | Private connectivity to SQL Server |
| Private DNS Zone | `privatelink.database.windows.net` | DNS resolution for private endpoint |
| Cosmos DB Account | `az305-lab-cosmos-<suffix>` | SQL (NoSQL) API, Session consistency, Serverless |
| Cosmos DB Database | `az305-lab-cosmosdb` | SQL database container |
| Cosmos DB Container | `items` | Partitioned container (`/category`) |
| Diagnostic Settings | 2 settings | SQL audit + Cosmos DB telemetry → Log Analytics |

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.5
- An Azure subscription with **Contributor** access
- Azure CLI authenticated: `az login`
- **Module 00 (Foundation)** deployed — provides VNet, database subnet, Log Analytics

## Usage

```bash
# 1. Navigate to the module directory
cd az305-lab/modules/07-databases

# 2. Copy and customise variables
cp terraform.tfvars.example terraform.tfvars
# Fill in the foundation module outputs (vnet_id, subnet_id, etc.)
# Optionally set allowed_client_ip to your public IP for direct SQL access

# 3. Initialise Terraform
terraform init

# 4. Preview changes
terraform plan

# 5. Deploy
terraform apply

# 6. Verify — check SQL Server connectivity
az sql server show --name $(terraform output -raw sql_server_name) \
  --resource-group $(terraform output -raw resource_group_name)

# List databases on the server
az sql db list --server $(terraform output -raw sql_server_name) \
  --resource-group $(terraform output -raw resource_group_name) \
  --output table

# Check Cosmos DB account
az cosmosdb show --name $(terraform output -raw cosmos_account_name) \
  --resource-group $(terraform output -raw resource_group_name)

# 7. Connect via Azure Data Studio or SSMS
#    Server: <sql_server_fqdn>
#    Auth: SQL Server Authentication
#    Login: sqladmin
#    Password: (retrieve from Terraform state — see note below)

# 8. Clean up
terraform destroy
```

### Retrieving the SQL Admin Password

The SQL admin password is generated by `random_password` and stored in
Terraform state. To retrieve it:

```bash
terraform show -json | jq -r '.values.root_module.resources[] | select(.address == "random_password.sql_admin") | .values.result'
```

> ⚠️ In production, store the password in Key Vault (Module 03) and reference it
> via a data source. Never store passwords in state files on shared backends
> without encryption.

## Inputs

| Variable | Type | Default | Description |
|---|---|---|---|
| `location` | `string` | `"eastus"` | Azure region |
| `prefix` | `string` | `"az305-lab"` | Naming prefix |
| `foundation_resource_group_name` | `string` | — | Foundation resource group name |
| `vnet_id` | `string` | — | Shared VNet resource ID |
| `database_subnet_id` | `string` | — | Database subnet resource ID |
| `log_analytics_workspace_id` | `string` | — | Log Analytics workspace resource ID |
| `sql_admin_username` | `string` | `"sqladmin"` | SQL Server admin login |
| `allowed_client_ip` | `string` | `"0.0.0.0"` | Client IP for SQL firewall |
| `tags` | `map(string)` | Lab defaults | Tags merged onto every resource |

## Outputs

| Output | Description |
|---|---|
| `resource_group_name` | Name of the databases resource group |
| `sql_server_name` | Globally unique SQL Server name |
| `sql_server_fqdn` | SQL Server FQDN (`<name>.database.windows.net`) |
| `sql_database_names` | List of SQL database names (Basic + Serverless) |
| `elastic_pool_name` | Name of the SQL Elastic Pool |
| `cosmos_account_name` | Globally unique Cosmos DB account name |
| `cosmos_endpoint` | Cosmos DB endpoint URI |
| `cosmos_database_name` | Name of the Cosmos DB SQL database |
| `private_endpoint_ip` | Private IP of the SQL Server endpoint |

## Dependencies

| Module | What It Provides |
|---|---|
| **00-foundation** | VNet, database subnet, Log Analytics workspace |

## Estimated Cost

| Resource | Estimated Daily Cost |
|---|---|
| SQL Database (Basic, 5 DTUs) | ~$0.17 |
| SQL Database (Serverless, paused) | ~$0.05 (storage only when paused) |
| SQL Elastic Pool (BasicPool, 50 eDTUs) | ~$0.50 |
| Cosmos DB (Serverless, idle) | ~$0.00 (pay per request only) |
| Private Endpoint | ~$0.24 |
| Private DNS Zone | ~$0.02 |
| SQL Server Auditing | Included |
| **Total (idle)** | **~$1/day** |
| **Total (active usage)** | **~$3/day** |

> **Tip:** Run `terraform destroy` when not actively studying to stop all charges.
> The serverless SQL database and Cosmos DB serverless both auto-pause when idle,
> minimising cost during inactive periods.

## Study Questions

1. When should you choose SQL Database vs SQL Managed Instance vs SQL on VM?
2. What is the difference between DTU and vCore purchasing models?
3. When is the serverless compute tier a good choice? When is it NOT?
4. How do elastic pools save cost for multi-tenant applications?
5. Name all five Cosmos DB consistency levels in order from strongest to weakest.
6. What makes a good Cosmos DB partition key? Give an example of a bad one.
7. What are the three components of the private endpoint pattern?
8. What is the difference between Active Geo-Replication and Auto-Failover Groups?
9. When would you choose Cosmos DB MongoDB API vs SQL (NoSQL) API?
10. What is the difference between TDE and Always Encrypted?
