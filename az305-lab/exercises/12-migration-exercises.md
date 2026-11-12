# Module 12: Migration — Exercises

## Exercise 1: Explore the Azure Migrate Project in the Portal
**Difficulty:** 🟢 Guided
**Method:** Portal / CLI
**Estimated Time:** 10 minutes

### Objective
Navigate the Azure Migrate hub to understand the tools and capabilities available for assessing and migrating workloads to Azure.

### Instructions
1. List Azure Migrate projects in the resource group:
   ```bash
   az resource list \
     --resource-group rg-az305-lab \
     --resource-type "Microsoft.Migrate/migrateProjects" \
     --output table
   ```
2. In the Azure Portal, navigate to Azure Migrate and explore the sections:
   - **Discovery and assessment:** Tools for discovering on-premises servers.
   - **Migration and modernization:** Tools for replicating and migrating servers.
   - **Data migration:** Azure Database Migration Service for database migrations.
   - **Web app migration:** Azure App Service migration assistant.
3. Review the supported scenarios:
   - VMware VMs to Azure (agentless or agent-based).
   - Hyper-V VMs to Azure.
   - Physical servers to Azure.
   - AWS/GCP VMs to Azure.
4. Understand the assessment types:
   - Azure VM assessment (size, cost, readiness).
   - Azure SQL assessment (SQL Server to Azure SQL migration paths).
   - Azure App Service assessment (web app migration readiness).
   - Azure VMware Solution (AVS) assessment.

### Success Criteria
- You can navigate the Azure Migrate hub and identify available tools.
- You understand the difference between discovery, assessment, and migration phases.
- You know which assessment types are available for different workload types.

### Explanation
Azure Migrate is the central hub for migration to Azure. AZ-305 tests whether you know the migration lifecycle: Discover (find servers and dependencies), Assess (readiness, sizing, cost), Migrate (replicate and cutover). The exam expects you to use Azure Migrate as the starting point for any migration, even if you use other tools (DMS for databases, App Service Migration Assistant for web apps). Dependency mapping is important for understanding application relationships.

---

## Exercise 2: Check DMS Status and Supported Migration Paths
**Difficulty:** 🟢 Guided
**Method:** CLI
**Estimated Time:** 10 minutes

### Objective
Inspect the Azure Database Migration Service (DMS) instance and understand which database migration paths it supports.

### Instructions
1. List DMS instances in the resource group:
   ```bash
   az dms list \
     --resource-group rg-az305-lab \
     --output table
   ```
2. View the DMS instance details:
   ```bash
   az dms show \
     --name <dms-name> \
     --resource-group rg-az305-lab \
     --output json | jq '{name, provisioningState, sku: .sku.name, virtualSubnetId}'
   ```
3. Review the supported migration paths:

   | Source | Target | Online? |
   |---|---|---|
   | SQL Server | Azure SQL Database | Yes |
   | SQL Server | Azure SQL Managed Instance | Yes |
   | SQL Server | SQL Server on Azure VM | Yes |
   | MySQL | Azure Database for MySQL | Yes |
   | PostgreSQL | Azure Database for PostgreSQL | Yes |
   | MongoDB | Azure Cosmos DB | Yes |
   | Oracle | Azure Database for PostgreSQL | No |

4. Check if there are any active migration projects:
   ```bash
   az dms project list \
     --service-name <dms-name> \
     --resource-group rg-az305-lab \
     --output table
   ```
5. Understand the difference between online and offline migration:
   - **Online:** Continuous replication, minimal downtime (minutes).
   - **Offline:** Full backup and restore, longer downtime (hours).

### Success Criteria
- You can identify the DMS instance and its provisioning state.
- You know which source-to-target migration paths DMS supports.
- You understand the difference between online and offline migration modes.

### Explanation
DMS is the primary database migration tool tested on AZ-305. The exam tests when to use DMS vs. native backup/restore vs. transactional replication. DMS online migration uses Change Data Capture (CDC) to minimize downtime. Key exam fact: DMS requires a VNet (it must be able to connect to the source database). For SQL Server to Azure SQL MI, DMS provides the smoothest migration path with minimal downtime.

---

## Exercise 3: Run an Assessment on the Simulated VM
**Difficulty:** 🟡 Intermediate
**Method:** Portal / CLI
**Estimated Time:** 20 minutes

### Objective
Create an Azure Migrate assessment for a simulated on-premises VM to determine the recommended Azure VM size, estimated cost, and migration readiness.

### Instructions
1. In the Azure Migrate project, navigate to the assessment section.
2. Create a new assessment with these parameters:
   - Assessment type: Azure VM.
   - Target location: same as your lab region.
   - Pricing tier: Pay-as-you-go.
   - Storage type: Premium managed disks.
   - Comfort factor: 1.3 (30% buffer over current utilization).
   - Performance history: 1 month.
   - Percentile utilization: 95th percentile.
3. Select the discovered servers to include in the assessment.
4. Review the assessment results:
   - **Readiness:** Ready, Conditionally Ready, Not Ready, Unknown.
   - **Recommended size:** Azure VM size based on CPU, memory, disk, and network.
   - **Monthly cost estimate:** Compute + storage.
   - **Issues and warnings:** Boot type (BIOS/UEFI), OS support, etc.
5. Export the assessment report for documentation.

### Success Criteria
- The assessment completes and shows VM readiness status.
- You can interpret the recommended VM size and understand why it was chosen.
- You understand the comfort factor and how it affects sizing.
- You can identify any readiness issues (unsupported OS, features, etc.).

### Explanation
AZ-305 tests assessment parameters. The comfort factor adds a buffer to account for peak usage not captured in the performance data. 95th percentile is recommended to avoid sizing based on outlier spikes. The exam tests "right-sizing" — choosing the smallest VM that meets performance requirements. Key insight: assessments are based on collected performance data, so the quality of the assessment depends on how long the appliance has been collecting data (recommend at least 1 month).

---

## Exercise 4: Plan a Migration Strategy for the Simulated Workload
**Difficulty:** 🟡 Intermediate
**Method:** Conceptual
**Estimated Time:** 25 minutes

### Objective
Create a migration plan for a simulated workload consisting of a web server, application server, and database server.

### Instructions
Plan the migration addressing:

1. **Dependency analysis:**
   - Which servers communicate with each other?
   - What ports and protocols are used?
   - Are there external dependencies (APIs, file shares)?
   - Use Azure Migrate dependency visualization or Service Map.

2. **Migration wave planning:**
   - Which servers should be migrated together (affinity groups)?
   - What is the migration order? (Database first? Web server first?)
   - How do you handle the dependency between web and database during migration?

3. **Migration method per server:**
   - Web server: rehost (lift-and-shift to VM) or refactor (App Service)?
   - Application server: rehost (VM) or replatform (Container)?
   - Database server: DMS online migration to Azure SQL MI.

4. **Cutover strategy:**
   - How do you minimize downtime during the cutover?
   - DNS cutover: when to update DNS records?
   - Rollback plan: how do you revert if something goes wrong?
   - Smoke testing: what do you test immediately after cutover?

5. **Post-migration:**
   - Decommission on-premises servers (when?).
   - Optimize Azure resources (right-size after migration).
   - Enable backup and monitoring.
   - Update documentation and runbooks.

### Success Criteria
- Dependencies are mapped and migration waves are defined.
- Each server has a specific migration method and tool.
- The cutover plan minimizes downtime and includes a rollback strategy.
- Post-migration tasks are documented.

### Explanation
AZ-305 tests migration planning methodology. The exam expects you to understand the migration phases: Assess, Plan, Migrate, Optimize. Key exam concepts: migration waves (groups of dependent servers migrated together), cutover windows (planned downtime for final switch), and rollback plans (ability to revert if migration fails). The exam also tests that you should optimize after migration, not just lift-and-shift (right-size VMs, enable auto-scaling, etc.).

---

## Exercise 5: Design a Complete Migration Plan for 100 Servers
**Difficulty:** 🔴 Challenge
**Method:** Conceptual
**Estimated Time:** 35 minutes

### Objective
Design a comprehensive migration plan for a 100-server on-premises environment, including discovery, assessment, migration strategy, and timeline.

### Instructions
The environment consists of:
- 40 Windows Server VMs (various roles: AD, file servers, web servers, app servers)
- 20 Linux VMs (web servers, application servers)
- 15 SQL Server instances (ranging from SQL 2012 to 2019)
- 10 legacy applications (some unsupported on Azure)
- 10 network appliances (firewalls, load balancers)
- 5 development/test environments

Design the migration plan:

1. **Discovery and inventory:**
   - Deploy Azure Migrate appliance for VM discovery.
   - Use Azure Migrate database assessment for SQL Servers.
   - Agent-based vs. agentless dependency analysis.
   - How long should discovery run before starting assessments? (1 month minimum)

2. **Classification using the 6 Rs:**
   For each workload type, recommend the appropriate strategy:
   - **Rehost** (lift-and-shift): which workloads?
   - **Replatform** (lift-and-optimize): which workloads?
   - **Refactor** (re-architect): which workloads?
   - **Repurchase** (replace with SaaS): which workloads?
   - **Retire** (decommission): which workloads?
   - **Retain** (keep on-premises): which workloads?

3. **Migration waves:**
   - Wave 0: Foundation (networking, identity, governance).
   - Wave 1: Low-risk, independent workloads (dev/test).
   - Wave 2: Moderate complexity (web servers, app servers).
   - Wave 3: Databases (using DMS with online migration).
   - Wave 4: Complex/legacy applications.
   - Wave 5: Final cutover and decommission.

4. **Landing zone preparation:**
   - Hub-spoke network topology.
   - Identity (Entra ID Connect sync).
   - Governance (management groups, policies, RBAC).
   - Monitoring (Log Analytics workspace, alerts).
   - Security (Azure Firewall, NSGs, Key Vault).

5. **Timeline and resources:**
   - Estimated duration for 100 servers (typically 6-12 months).
   - Team structure and skills needed.
   - Stakeholder communication plan.

6. **Risk mitigation:**
   - What are the top risks and mitigations?
   - How do you handle unsupported legacy applications?
   - What is the rollback strategy for each wave?

### Success Criteria
- All 100 servers are classified with a migration strategy (6 Rs).
- Migration waves are logically ordered with dependencies respected.
- The landing zone is designed before any workload migration begins.
- A realistic timeline accounts for discovery, testing, and cutover.
- Risks are identified with mitigation strategies.

### Explanation
Large-scale migration planning is a major AZ-305 topic. The exam tests the Cloud Adoption Framework (CAF) migration methodology: Define Strategy, Plan, Ready (landing zone), Adopt (migrate), Govern, Manage. Key exam insight: the landing zone (networking, identity, governance) must be established before migrating any workloads. The 6 Rs framework is essential for classifying workloads. Common exam trap: trying to refactor everything (expensive and slow). Most workloads should be rehosted first, then optimized post-migration.

---

## Exercise 6: Classify Workloads Using the R Strategies
**Difficulty:** 🔴 Challenge
**Method:** Conceptual
**Estimated Time:** 30 minutes

### Objective
**Scenario:** A company has the following servers. Classify each with the appropriate R strategy (Rehost, Replatform, Refactor, Repurchase, Retire, Retain) and recommend the target Azure service.

### Instructions
Classify each workload:

**1. Five SQL Server instances:**
- SQL Server 2019 (ERP database, 500 GB, high IOPS):
  - Strategy: ?
  - Target: ?
  - Migration tool: ?

- SQL Server 2016 (reporting database, 200 GB, read-heavy):
  - Strategy: ?
  - Target: ?
  - Migration tool: ?

- SQL Server 2012 (legacy CRM, 50 GB, deprecated in 6 months):
  - Strategy: ?
  - Target: ?
  - Migration tool: ?

- SQL Server 2019 (data warehouse, 2 TB, complex ETL):
  - Strategy: ?
  - Target: ?
  - Migration tool: ?

- SQL Server 2014 (custom app, uses CLR, Service Broker):
  - Strategy: ?
  - Target: ?
  - Migration tool: ?

**2. Twenty web servers:**
- 10 IIS servers running .NET 4.8 applications:
  - Strategy: ?
  - Target: ?

- 5 Apache servers running PHP applications:
  - Strategy: ?
  - Target: ?

- 5 Nginx servers running Node.js applications:
  - Strategy: ?
  - Target: ?

**3. Ten file servers:**
- 5 Windows file servers (total 10 TB):
  - Strategy: ?
  - Target: Azure Files, Azure Blob, or Azure NetApp Files?

- 3 NFS servers for Linux workloads:
  - Strategy: ?
  - Target: ?

- 2 FTP servers:
  - Strategy: ?
  - Target: ?

**4. Other servers:**
- 3 Active Directory domain controllers:
  - Strategy: ?
  - Target: Entra Domain Services or DC VMs?

- 2 SMTP relay servers:
  - Strategy: ?
  - Target: SendGrid, Azure Communication Services, or Exchange Online?

- Exchange Server 2016:
  - Strategy: ?
  - Target: ?

### Success Criteria
- Each workload has a justified R strategy.
- Target Azure service is appropriate for the workload characteristics.
- Migration tools are correctly identified for each path.
- Trade-offs between strategies are explained (cost, effort, time, risk).

### Explanation
The 6 Rs classification is fundamental to AZ-305. The exam expects you to match workloads to the most appropriate strategy:
- **Rehost:** VMs to Azure VMs. Fast, low risk, but doesn't optimize for cloud.
- **Replatform:** VMs to PaaS with minor changes (e.g., SQL to Azure SQL MI). Moderate effort, good optimization.
- **Refactor:** Rewrite for cloud-native (e.g., monolith to microservices). High effort, best optimization.
- **Repurchase:** Replace with SaaS (e.g., Exchange to Microsoft 365). Quick, but may lose customization.
- **Retire:** Decommission unused servers. Free savings.
- **Retain:** Keep on-premises (compliance, legacy, not worth migrating). Reassess later.

The exam penalizes over-engineering (refactoring simple web servers) and under-engineering (rehosting databases that would benefit from PaaS features).
