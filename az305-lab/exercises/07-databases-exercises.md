# Module 07: Database Solutions — Exercises

## Exercise 1: Connect to Azure SQL Using CLI and Run a Query
**Difficulty:** 🟢 Guided
**Method:** CLI
**Estimated Time:** 10 minutes

### Objective
Connect to an Azure SQL Database using the Azure CLI and execute a basic query to verify connectivity and understand the access model.

### Instructions
1. List Azure SQL servers in the resource group:
   ```bash
   az sql server list \
     --resource-group rg-az305-lab \
     --output table \
     --query "[].{Name:name, FQDN:fullyQualifiedDomainName, AdminLogin:administratorLogin}"
   ```
2. List databases on the server:
   ```bash
   az sql db list \
     --server <server-name> \
     --resource-group rg-az305-lab \
     --output table \
     --query "[].{Name:name, Edition:sku.tier, MaxSize:maxSizeBytes, Status:status}"
   ```
3. Check the server's firewall rules:
   ```bash
   az sql server firewall-rule list \
     --server <server-name> \
     --resource-group rg-az305-lab \
     --output table
   ```
4. Connect and run a query (if sqlcmd is available):
   ```bash
   az sql db show-connection-string \
     --server <server-name> \
     --name <database-name> \
     --client sqlcmd \
     --output tsv
   ```
5. Alternatively, use the Azure CLI to query:
   ```bash
   az sql db show \
     --name <database-name> \
     --server <server-name> \
     --resource-group rg-az305-lab \
     --output json | jq '{name, edition: .sku.tier, serviceObjective: .sku.name, maxSizeGB: (.maxSizeBytes / 1073741824)}'
   ```

### Success Criteria
- You can list SQL servers and databases in the resource group.
- You can identify the pricing tier and maximum size of the database.
- You understand how firewall rules control access to the SQL server.

### Explanation
AZ-305 tests Azure SQL deployment decisions. The exam expects you to know that Azure SQL Database is a PaaS offering (Microsoft manages the infrastructure), that firewall rules control network access, and that Entra ID authentication is preferred over SQL authentication. You should also know the difference between Azure SQL Database (single database/elastic pool), Azure SQL Managed Instance (near 100% SQL Server compatibility), and SQL Server on Azure VMs (full control).

---

## Exercise 2: Check Cosmos DB Consistency Level Setting
**Difficulty:** 🟢 Guided
**Method:** CLI
**Estimated Time:** 10 minutes

### Objective
Inspect the consistency level configured on a Cosmos DB account and understand the five consistency models.

### Instructions
1. List Cosmos DB accounts in the resource group:
   ```bash
   az cosmosdb list \
     --resource-group rg-az305-lab \
     --output table \
     --query "[].{Name:name, Kind:kind, DefaultConsistency:consistencyPolicy.defaultConsistencyLevel}"
   ```
2. View the detailed consistency configuration:
   ```bash
   az cosmosdb show \
     --name <cosmosdb-account-name> \
     --resource-group rg-az305-lab \
     --output json | jq '{defaultConsistency: .consistencyPolicy.defaultConsistencyLevel, maxIntervalInSeconds: .consistencyPolicy.maxIntervalInSeconds, maxStalenessPrefix: .consistencyPolicy.maxStalenessPrefix}'
   ```
3. List the read regions and write regions:
   ```bash
   az cosmosdb show \
     --name <cosmosdb-account-name> \
     --resource-group rg-az305-lab \
     --output json | jq '{writeLocations: .writeLocations, readLocations: .readLocations}'
   ```
4. Review the five consistency levels (strongest to weakest):
   - **Strong** — linearizable reads, highest latency, single-region writes only
   - **Bounded Staleness** — reads lag behind writes by at most K versions or T time
   - **Session** — consistent within a client session (DEFAULT and most commonly used)
   - **Consistent Prefix** — reads never see out-of-order writes
   - **Eventual** — no ordering guarantee, lowest latency

### Success Criteria
- You can identify the default consistency level on the Cosmos DB account.
- You can list read and write regions.
- You can explain the trade-offs between the five consistency levels.

### Explanation
Cosmos DB consistency levels are a top AZ-305 exam topic. The exam presents scenarios and expects you to choose the right consistency model. Session consistency is the default and correct answer for most scenarios (user sees their own writes). Strong consistency is needed when absolute ordering matters (financial transactions) but limits you to single-region writes and adds latency. Eventual consistency provides the lowest latency and highest throughput but no ordering guarantees.

---

## Exercise 3: Compare DTU and vCore Pricing for a Workload
**Difficulty:** 🟡 Intermediate
**Method:** Portal / Calculator
**Estimated Time:** 20 minutes

### Objective
Compare the DTU-based and vCore-based purchasing models for Azure SQL Database to determine which is more cost-effective for a given workload.

### Instructions
Using the Azure Pricing Calculator or documentation, compare costs for this workload:
- 200 concurrent users
- 50 transactions per second
- 100 GB database size
- Region: East US
- Standard availability (no zone redundancy)

**DTU model configuration:**
1. Estimate the DTU requirement (rule of thumb: 1 DTU per simple transaction per second).
2. Find the Standard tier service objective that provides sufficient DTUs.
3. Calculate monthly cost.

**vCore model configuration:**
1. Choose General Purpose tier with provisioned compute.
2. Select an appropriate number of vCores (start with 4 vCores).
3. Add storage cost (100 GB).
4. Calculate monthly cost.

**Serverless option:**
1. Configure the same workload with serverless compute.
2. Set auto-pause delay and min/max vCores.
3. Estimate cost based on actual usage patterns (assume 8 hours active per day).

Compare all three options in a table.

### Success Criteria
- You have a cost comparison table for DTU, vCore provisioned, and vCore serverless.
- You can explain when each model is more cost-effective.
- You understand that DTU bundles compute, memory, and I/O, while vCore separates compute from storage.

### Explanation
AZ-305 frequently asks you to choose between DTU and vCore models. Key guidance: DTU is simpler and good for predictable workloads. vCore provides more flexibility, supports reserved capacity (1-3 year discounts), and offers serverless for intermittent workloads. The exam expects you to recommend vCore for most new deployments and serverless when usage is unpredictable with idle periods. DTU-to-vCore migration is a supported and common exam scenario.

---

## Exercise 4: Create a Cosmos DB Item and Query by Partition Key
**Difficulty:** 🟡 Intermediate
**Method:** CLI
**Estimated Time:** 20 minutes

### Objective
Create items in a Cosmos DB container and query them using the partition key to understand how partitioning affects query performance.

### Instructions
1. List databases in the Cosmos DB account:
   ```bash
   az cosmosdb sql database list \
     --account-name <cosmosdb-account-name> \
     --resource-group rg-az305-lab \
     --output table
   ```
2. List containers in a database:
   ```bash
   az cosmosdb sql container list \
     --account-name <cosmosdb-account-name> \
     --resource-group rg-az305-lab \
     --database-name <database-name> \
     --output table \
     --query "[].{Name:name, PartitionKey:resource.partitionKey.paths[0]}"
   ```
3. Note the partition key path (e.g., `/categoryId` or `/tenantId`).
4. Create an item in the container:
   ```bash
   az cosmosdb sql container invoke-stored-procedure ... # or use the portal Data Explorer
   ```
   Alternatively, use the Azure Portal Data Explorer to insert items with different partition key values.
5. Query items within a single partition (efficient, single-partition query):
   ```sql
   SELECT * FROM c WHERE c.categoryId = "electronics"
   ```
6. Query items across partitions (cross-partition query, less efficient):
   ```sql
   SELECT * FROM c WHERE c.price > 100
   ```
7. Compare the Request Unit (RU) charge for single-partition vs. cross-partition queries.

### Success Criteria
- You can create items with specific partition key values.
- You observe that single-partition queries consume fewer RUs than cross-partition queries.
- You can explain why partition key selection is the most important Cosmos DB design decision.

### Explanation
Partition key design is critical for AZ-305. The exam tests whether you know that a good partition key has high cardinality, even distribution, and is included in most queries. Bad partition keys cause "hot partitions" (uneven data distribution). The exam may ask you to choose between `/userId`, `/region`, `/timestamp` as partition keys for specific scenarios. Cross-partition queries are expensive and should be avoided in high-throughput scenarios.

---

## Exercise 5: Configure Geo-Replication for the SQL Database
**Difficulty:** 🟡 Intermediate
**Method:** CLI
**Estimated Time:** 20 minutes

### Objective
Set up active geo-replication for an Azure SQL Database and understand the replication topology for disaster recovery.

### Instructions
1. View the current replication status of the database:
   ```bash
   az sql db replica list-links \
     --name <database-name> \
     --server <server-name> \
     --resource-group rg-az305-lab \
     --output table
   ```
2. Create a secondary server in a different region (if not already exists):
   ```bash
   az sql server create \
     --name <secondary-server-name> \
     --resource-group rg-az305-lab \
     --location <secondary-region> \
     --admin-user <admin-login> \
     --admin-password <password>
   ```
3. Create a geo-replica:
   ```bash
   az sql db replica create \
     --name <database-name> \
     --server <server-name> \
     --resource-group rg-az305-lab \
     --partner-server <secondary-server-name> \
     --partner-resource-group rg-az305-lab
   ```
4. Verify the replication link is established and healthy:
   ```bash
   az sql db replica list-links \
     --name <database-name> \
     --server <server-name> \
     --resource-group rg-az305-lab \
     --output json | jq '.[0] | {role, partnerRole, replicationState, percentComplete}'
   ```
5. Consider creating a failover group instead of manual geo-replication for automatic failover.

### Success Criteria
- A geo-replica exists in a secondary region.
- The replication link shows "CATCH_UP" or "SEEDING" status initially, then "SYNCHRONIZED."
- You understand the difference between active geo-replication and auto-failover groups.

### Explanation
The exam tests geo-replication vs. auto-failover groups. Active geo-replication gives you up to 4 readable secondaries but requires manual failover and application connection string changes. Auto-failover groups provide automatic failover with a listener endpoint that redirects transparently. The exam almost always favors auto-failover groups for production DR scenarios because they simplify the failover process and eliminate application changes.

---

## Exercise 6: Design a Database Architecture for a Multi-Tenant SaaS Application
**Difficulty:** 🔴 Challenge
**Method:** Conceptual
**Estimated Time:** 30 minutes

### Objective
Design the database tier for a multi-tenant SaaS application that serves 500 customers, ranging from small (10 users) to enterprise (10,000 users).

### Instructions
Evaluate three multi-tenancy models:

1. **Database per tenant:**
   - Each tenant gets their own database.
   - Pros: complete isolation, easy to customize, simple backup/restore per tenant.
   - Cons: high management overhead, expensive at scale.
   - Best for: enterprise tenants with strict isolation requirements.

2. **Shared database, schema per tenant:**
   - One database, separate schemas for each tenant.
   - Pros: moderate isolation, shared resources.
   - Cons: schema management complexity, moderate isolation.
   - Best for: medium-sized tenants.

3. **Shared database, shared schema:**
   - One database, tenant ID column in every table.
   - Pros: lowest cost, simplest management.
   - Cons: noisy neighbor risk, hardest to isolate, data leakage risk.
   - Best for: small tenants with low throughput.

Design a hybrid approach:
- Enterprise tenants: dedicated databases (Azure SQL Database).
- Standard tenants: elastic pool with database-per-tenant.
- Free/small tenants: shared database with tenant ID column.

Address:
- How does elastic pool help with cost optimization?
- How do you prevent noisy neighbor problems?
- How do you handle tenant onboarding and offboarding?
- What is the data migration strategy when a tenant upgrades tiers?

### Success Criteria
- The hybrid model optimally balances cost and isolation.
- Elastic pools are used for medium tenants to share DTUs/vCores.
- Enterprise tenants have dedicated resources with predictable performance.
- A tenant upgrade/downgrade path exists.
- Data isolation is ensured at every tier.

### Explanation
Multi-tenant database design is a classic AZ-305 scenario. The exam tests whether you know that elastic pools allow multiple databases to share resources (cost-effective for variable workloads), that Row-Level Security (RLS) can enforce tenant isolation in shared databases, and that Azure SQL Database supports up to 500 databases per elastic pool. Cosmos DB is also a valid choice for multi-tenant scenarios using partition key per tenant.

---

## Exercise 7: Recommend a Migration Target for Legacy SQL Server
**Difficulty:** 🔴 Challenge
**Method:** Conceptual
**Estimated Time:** 30 minutes

### Objective
**Scenario:** A company has a legacy SQL Server 2016 on-premises with the following characteristics:
- 2 TB database size
- 200 concurrent users
- 10ms query latency requirement
- Uses SQL Agent jobs, CLR assemblies, and cross-database queries
- Uses Service Broker for messaging
- Linked servers to two other SQL instances
- 99.99% uptime requirement

Recommend the Azure SQL deployment model and service tier.

### Instructions
Evaluate each option against the requirements:

1. **Azure SQL Database (Single Database):**
   - Maximum size: 4 TB (Hyperscale: 100 TB).
   - Does it support SQL Agent jobs? (No, use Elastic Jobs)
   - Does it support CLR? (Limited)
   - Does it support cross-database queries? (No, use Elastic Query)
   - Does it support Service Broker? (No)
   - Does it support linked servers? (No)

2. **Azure SQL Managed Instance:**
   - Maximum size: 16 TB.
   - SQL Agent: Yes.
   - CLR: Yes.
   - Cross-database queries: Yes (within the same instance).
   - Service Broker: Yes (within the same instance).
   - Linked servers: Yes.
   - Near 100% SQL Server feature compatibility.

3. **SQL Server on Azure VM:**
   - Full SQL Server: all features supported.
   - You manage OS patches, backups, HA.
   - Higher operational overhead but maximum compatibility.

4. **Azure SQL Database Hyperscale:**
   - Supports up to 100 TB.
   - Fast scaling and near-instant backups.
   - But same feature limitations as SQL Database.

For the recommended option, also specify:
- Service tier (General Purpose vs. Business Critical).
- Compute size (vCores or DTUs).
- HA configuration for 99.99% SLA.
- Migration approach (DMS, backup/restore, etc.).

### Success Criteria
- SQL Managed Instance is recommended (or SQL on VM with strong justification).
- The recommendation addresses every feature requirement (SQL Agent, CLR, Service Broker, linked servers).
- Business Critical tier is recommended for 10ms latency and 99.99% SLA.
- A migration plan using DMS or native backup/restore is included.

### Explanation
This is a textbook AZ-305 question. The presence of SQL Agent, CLR, Service Broker, and linked servers eliminates Azure SQL Database. SQL Managed Instance supports all these features and is the PaaS option with near-complete SQL Server compatibility. SQL Server on VM is only recommended when MI lacks a specific feature (e.g., FILESTREAM, cross-instance distributed transactions). Business Critical tier provides in-memory OLTP, has a built-in read replica, and offers 99.99% SLA. General Purpose tier uses remote storage and offers 99.99% with zone redundancy.
