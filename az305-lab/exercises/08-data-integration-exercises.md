# Module 08: Data Integration — Exercises

## Exercise 1: Explore Data Factory Pipeline in the Portal
**Difficulty:** 🟢 Guided
**Method:** Portal / CLI
**Estimated Time:** 10 minutes

### Objective
Navigate the Azure Data Factory interface to understand the components of a data integration pipeline: datasets, linked services, pipelines, and triggers.

### Instructions
1. List Data Factory instances in the resource group:
   ```bash
   az datafactory list \
     --resource-group rg-az305-lab \
     --output table \
     --query "[].{Name:name, Location:location, ProvisioningState:provisioningState}"
   ```
2. List pipelines in the Data Factory:
   ```bash
   az datafactory pipeline list \
     --factory-name <factory-name> \
     --resource-group rg-az305-lab \
     --output table
   ```
3. View the details of a pipeline:
   ```bash
   az datafactory pipeline show \
     --factory-name <factory-name> \
     --resource-group rg-az305-lab \
     --name <pipeline-name> \
     --output json | jq '{name, activities: [.activities[].name], parameters}'
   ```
4. List linked services (connections to data sources and sinks):
   ```bash
   az datafactory linked-service list \
     --factory-name <factory-name> \
     --resource-group rg-az305-lab \
     --output table
   ```
5. List triggers configured on the Data Factory:
   ```bash
   az datafactory trigger list \
     --factory-name <factory-name> \
     --resource-group rg-az305-lab \
     --output table
   ```

### Success Criteria
- You can identify the main components: pipelines, activities, linked services, datasets, triggers.
- You understand the relationship between these components.
- You can describe the data flow: source (linked service) through pipeline (activities) to sink (linked service).

### Explanation
AZ-305 tests Data Factory as the primary data integration service. The exam expects you to know the components: Linked Services (connections), Datasets (data structures), Pipelines (orchestration), Activities (actions like Copy, Data Flow, Stored Procedure), and Triggers (schedule, tumbling window, event-based). Understanding when to use Data Factory vs. Azure Synapse pipelines (same engine, integrated in Synapse) is also tested.

---

## Exercise 2: List Data Lake Gen2 Containers and Examine ACLs
**Difficulty:** 🟢 Guided
**Method:** CLI
**Estimated Time:** 10 minutes

### Objective
Explore the Data Lake Storage Gen2 hierarchy (containers, directories, files) and understand the ACL (Access Control List) security model.

### Instructions
1. Verify the storage account has hierarchical namespace enabled (Data Lake Gen2):
   ```bash
   az storage account show \
     --name <storage-account-name> \
     --output json | jq '{isHnsEnabled: .isHnsEnabled, kind: .kind}'
   ```
2. List file systems (containers) in the Data Lake:
   ```bash
   az storage fs list \
     --account-name <storage-account-name> \
     --auth-mode login \
     --output table
   ```
3. List directories and files in a container:
   ```bash
   az storage fs file list \
     --file-system <container-name> \
     --account-name <storage-account-name> \
     --auth-mode login \
     --output table
   ```
4. View ACLs on a directory:
   ```bash
   az storage fs access show \
     --file-system <container-name> \
     --path <directory-path> \
     --account-name <storage-account-name> \
     --auth-mode login \
     --output json
   ```
5. Understand the ACL format: `user::rwx,group::r-x,other::---,user:<object-id>:rwx`.

### Success Criteria
- You can identify Data Lake Gen2 by the hierarchical namespace feature.
- You can navigate the directory structure and list files.
- You can read and interpret POSIX-style ACLs on directories and files.
- You understand the difference between access ACLs and default ACLs.

### Explanation
Data Lake Gen2 combines blob storage with a hierarchical file system and POSIX ACLs. AZ-305 tests when to use Data Lake Gen2 vs. regular Blob Storage. Data Lake Gen2 is preferred when you need directory-level security (ACLs), hierarchical organization, and integration with analytics services (Synapse, Databricks, HDInsight). The exam also tests that RBAC and ACLs work together: RBAC is evaluated first, and ACLs provide finer-grained control.

---

## Exercise 3: Trigger the Sample Data Factory Pipeline and Monitor Execution
**Difficulty:** 🟡 Intermediate
**Method:** CLI / Portal
**Estimated Time:** 20 minutes

### Objective
Manually trigger a Data Factory pipeline, monitor its execution, and review the activity run details.

### Instructions
1. Trigger the pipeline manually:
   ```bash
   az datafactory pipeline create-run \
     --factory-name <factory-name> \
     --resource-group rg-az305-lab \
     --name <pipeline-name>
   ```
2. Note the `runId` from the output.
3. Check the pipeline run status:
   ```bash
   az datafactory pipeline-run show \
     --factory-name <factory-name> \
     --resource-group rg-az305-lab \
     --run-id <run-id> \
     --output json | jq '{status, runStart, runEnd, durationInMs, message}'
   ```
4. List the activity runs within the pipeline run:
   ```bash
   az datafactory activity-run query-by-pipeline-run \
     --factory-name <factory-name> \
     --resource-group rg-az305-lab \
     --run-id <run-id> \
     --last-updated-after "2024-01-01T00:00:00Z" \
     --last-updated-before "2030-01-01T00:00:00Z" \
     --output json | jq '.value[] | {activityName, status, durationInMs, error}'
   ```
5. If an activity failed, examine the error message and determine the root cause.

### Success Criteria
- The pipeline is triggered and you can track its execution status.
- You can view individual activity run results.
- You understand the pipeline run lifecycle: Queued, InProgress, Succeeded, Failed, Cancelled.

### Explanation
Monitoring Data Factory pipelines is important for AZ-305 operational design. The exam tests whether you know about built-in monitoring (Monitor tab in Data Factory Studio), Azure Monitor integration (diagnostic settings to Log Analytics), and alerting on pipeline failures. Data Factory also supports retry policies on activities, which is a common exam topic for handling transient failures.

---

## Exercise 4: Upload Data to the Bronze Layer and Verify Event Trigger
**Difficulty:** 🟡 Intermediate
**Method:** CLI
**Estimated Time:** 20 minutes

### Objective
Upload data to a Data Lake "bronze" (raw) layer and verify that an event-based trigger in Data Factory detects the new file.

### Instructions
1. Create a test CSV file:
   ```bash
   echo "id,name,amount,date" > sample-data.csv
   echo "1,Widget A,29.99,2024-01-15" >> sample-data.csv
   echo "2,Widget B,49.99,2024-01-16" >> sample-data.csv
   echo "3,Widget C,19.99,2024-01-17" >> sample-data.csv
   ```
2. Upload to the bronze layer:
   ```bash
   az storage fs file upload \
     --file-system bronze \
     --path incoming/sample-data.csv \
     --source sample-data.csv \
     --account-name <storage-account-name> \
     --auth-mode login
   ```
3. Check if an event trigger is configured for the bronze container:
   ```bash
   az datafactory trigger show \
     --factory-name <factory-name> \
     --resource-group rg-az305-lab \
     --name <trigger-name> \
     --output json | jq '{type, runtimeState, pipeline}'
   ```
4. Check the trigger run history:
   ```bash
   az datafactory trigger-run query-by-factory \
     --factory-name <factory-name> \
     --resource-group rg-az305-lab \
     --last-updated-after "2024-01-01T00:00:00Z" \
     --last-updated-before "2030-01-01T00:00:00Z" \
     --output json | jq '.value[] | {triggerName, status, triggerRunTimestamp}'
   ```
5. If the trigger fired, verify the pipeline ran and processed the file.

### Success Criteria
- The file is uploaded to the bronze layer successfully.
- The event trigger detects the file upload (if configured and running).
- The corresponding pipeline runs and processes the new data.

### Explanation
Event-driven data ingestion is a key AZ-305 pattern. The exam tests whether you know that Data Factory supports three trigger types: Schedule (cron-like), Tumbling Window (fixed-size time intervals, supports dependencies), and Storage Event (blob created/deleted). The medallion architecture (bronze/silver/gold) is a common data lake pattern: bronze = raw data, silver = cleaned/transformed, gold = aggregated/business-ready. Event triggers enable near-real-time ingestion.

---

## Exercise 5: Design a Data Integration Pipeline for ETL from On-Premises SQL
**Difficulty:** 🔴 Challenge
**Method:** Conceptual
**Estimated Time:** 30 minutes

### Objective
Design an end-to-end ETL pipeline that extracts data from an on-premises SQL Server, transforms it, and loads it into Azure Data Lake for analytics.

### Instructions
Design the solution addressing:

1. **Connectivity:**
   - How does Data Factory connect to on-premises SQL Server?
   - What is a Self-Hosted Integration Runtime (SHIR)?
   - Where should the SHIR be installed? (On-premises network)
   - How do you make SHIR highly available? (Multiple nodes)

2. **Extraction:**
   - Full extraction vs. incremental extraction: trade-offs?
   - How do you implement Change Data Capture (CDC) for incremental loads?
   - What is the watermark pattern for tracking changes?

3. **Transformation:**
   - Data Factory Mapping Data Flows vs. external compute (Databricks, Synapse)?
   - When to transform in Data Factory vs. when to use Spark?
   - How do you handle schema drift (source schema changes)?

4. **Loading:**
   - Data Lake target format: Parquet, Delta Lake, CSV?
   - Medallion architecture: where does each transformation stage land?
   - How do you handle duplicate data (idempotent loads)?

5. **Orchestration:**
   - How do you chain multiple pipelines (dependencies)?
   - Error handling and retry strategy.
   - How do you notify stakeholders on failure?

6. **Security:**
   - Credentials for on-premises SQL: where stored? (Key Vault)
   - Data encryption in transit and at rest.
   - Network path: SHIR to Data Factory uses outbound HTTPS (no inbound ports needed).

### Success Criteria
- Self-Hosted Integration Runtime is used for on-premises connectivity.
- Incremental extraction with watermarks or CDC is implemented.
- Data lands in Parquet format in a Data Lake medallion architecture.
- Pipeline handles failures with retries and alerting.
- Credentials are stored in Key Vault, not in Data Factory linked services.

### Explanation
This is a complete AZ-305 data integration scenario. The exam heavily tests Self-Hosted Integration Runtime as the bridge between on-premises and cloud. Key facts: SHIR requires outbound HTTPS only (no inbound firewall rules), can be installed on multiple machines for HA, and supports both Data Factory and Synapse. The exam also tests Copy Activity performance: use parallel copies, staged copy (via staging storage), and PolyBase for loading into Synapse.

---

## Exercise 6: Design a Unified Analytics Platform for Multiple Data Sources
**Difficulty:** 🔴 Challenge
**Method:** Conceptual
**Estimated Time:** 30 minutes

### Objective
**Scenario:** Three on-premises databases (SQL Server ERP, MySQL CRM, MongoDB product catalog) need to be integrated into a unified analytics platform. The business needs a single view of customers, products, and orders for reporting and machine learning.

Design the data architecture.

### Instructions
Address the following:

1. **Ingestion layer:**
   - Which Azure service orchestrates data movement from three different sources?
   - How do you handle the different source types (SQL, MySQL, MongoDB)?
   - Batch vs. real-time ingestion: which for each source?
   - How do you handle different data formats and schemas?

2. **Storage layer:**
   - Azure Data Lake Gen2 as the central data lake.
   - Medallion architecture design:
     - Bronze: raw data from each source (original format).
     - Silver: cleaned, standardized, and joined data.
     - Gold: business-ready aggregates and ML feature stores.

3. **Processing layer:**
   - Azure Synapse Analytics vs. Azure Databricks: selection criteria?
   - How do you create the unified customer view (entity resolution)?
   - How do you handle schema mapping between different source systems?

4. **Serving layer:**
   - Power BI for business reporting: connects to which layer?
   - Azure ML for machine learning: reads from which layer?
   - API access for applications: how is data served?

5. **Data governance:**
   - Microsoft Purview for data catalog and lineage.
   - How do you track data lineage from source to gold layer?
   - Classification and sensitivity labeling for PII.

6. **Data quality:**
   - How do you validate data at each layer transition?
   - How do you handle data quality issues (missing values, duplicates, format errors)?
   - Alerting on data quality degradation.

### Success Criteria
- Data Factory (or Synapse Pipelines) orchestrates ingestion from all three sources.
- Data Lake Gen2 stores data in medallion architecture with Parquet/Delta format.
- Synapse or Databricks processes transformations.
- Power BI connects to the gold layer for reporting.
- Purview provides data catalog, lineage, and governance.

### Explanation
This is an enterprise data architecture question for AZ-305. The exam tests whether you know the modern data platform components: Data Factory for orchestration, Data Lake for storage, Synapse/Databricks for processing, Power BI for visualization, and Purview for governance. The medallion architecture is the recommended pattern. Key decision: Synapse vs. Databricks. Synapse is better integrated with the Microsoft ecosystem, while Databricks is preferred for advanced ML workloads and multi-cloud scenarios.
