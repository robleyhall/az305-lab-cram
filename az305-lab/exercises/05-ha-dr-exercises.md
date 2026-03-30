# Module 05: High Availability & Disaster Recovery — Exercises

## Exercise 1: Verify VMs Are in the Correct Availability Set/Zone
**Difficulty:** 🟢 Guided
**Method:** CLI
**Estimated Time:** 10 minutes

### Objective
Inspect VM placement to verify that high availability configurations are correctly applied.

### Instructions
1. List all VMs in the lab resource group with their availability information:
   ```bash
   az vm list \
     --resource-group rg-az305-lab \
     --output table \
     --query "[].{Name:name, Zone:zones[0], AvailabilitySet:availabilitySet.id, Size:hardwareProfile.vmSize}"
   ```
2. If VMs are in an availability set, inspect the set's configuration:
   ```bash
   az vm availability-set show \
     --name <availability-set-name> \
     --resource-group rg-az305-lab \
     --output json | jq '{faultDomainCount: .platformFaultDomainCount, updateDomainCount: .platformUpdateDomainCount, sku: .sku.name}'
   ```
3. If VMs use availability zones, verify the zone distribution:
   ```bash
   az vm list \
     --resource-group rg-az305-lab \
     --output table \
     --query "[].{Name:name, Zone:zones[0], Location:location}"
   ```
4. Check whether the VM sizes support availability zones in the current region:
   ```bash
   az vm list-skus \
     --location <region> \
     --size Standard_B2s \
     --output table \
     --query "[].{Name:name, Zones:locationInfo[0].zones}"
   ```

### Success Criteria
- You can identify whether VMs use availability sets or availability zones.
- You know the fault domain and update domain counts for availability sets.
- You understand that availability zones provide higher SLA (99.99%) than availability sets (99.95%).

### Explanation
AZ-305 tests HA design extensively. Key facts: Availability Zones = physically separate datacenters within a region (99.99% SLA). Availability Sets = logical grouping within a single datacenter using fault domains and update domains (99.95% SLA). A single VM with Premium SSD gets 99.9% SLA. The exam expects you to choose the right option based on SLA requirements and regional availability.

---

## Exercise 2: Check Load Balancer Health Probe Status
**Difficulty:** 🟢 Guided
**Method:** CLI
**Estimated Time:** 10 minutes

### Objective
Verify that a load balancer's health probes are correctly detecting healthy and unhealthy backend instances.

### Instructions
1. List load balancers in the resource group:
   ```bash
   az network lb list \
     --resource-group rg-az305-lab \
     --output table
   ```
2. View the health probe configuration:
   ```bash
   az network lb probe list \
     --lb-name <lb-name> \
     --resource-group rg-az305-lab \
     --output json | jq '.[] | {name, protocol, port, intervalInSeconds, numberOfProbes, requestPath}'
   ```
3. Check the backend pool members and their health:
   ```bash
   az network lb address-pool list \
     --lb-name <lb-name> \
     --resource-group rg-az305-lab \
     --output json | jq '.[].backendIPConfigurations[].id'
   ```
4. View load balancer metrics for health probe status (in Portal or via metrics API):
   ```bash
   az monitor metrics list \
     --resource <lb-resource-id> \
     --metric "DipAvailability" \
     --output table
   ```
   A value of 100 means all backend instances are healthy; 0 means all are down.

### Success Criteria
- You can identify the health probe configuration (protocol, port, path, interval).
- You can determine which backend instances are healthy.
- You understand that the health probe status metric (DipAvailability) shows backend health.

### Explanation
Health probes are critical for HA. The exam tests whether you know that: HTTP probes can check a specific path (recommended for application health), TCP probes only verify port connectivity, probes run from the Azure infrastructure (not from your VNet), and an unhealthy instance is removed from rotation after the configured number of consecutive failures.

---

## Exercise 3: Simulate a VM Failure and Observe LB Behavior
**Difficulty:** 🟡 Intermediate
**Method:** CLI
**Estimated Time:** 20 minutes

### Objective
Simulate a backend failure by stopping a VM behind a load balancer and verify that traffic fails over to healthy instances.

### Instructions
1. Identify the VMs in the load balancer backend pool.
2. From a client (or using curl), verify you can reach the application through the load balancer's frontend IP:
   ```bash
   curl http://<lb-frontend-ip>
   ```
3. Stop one of the backend VMs:
   ```bash
   az vm stop \
     --name <vm-name> \
     --resource-group rg-az305-lab
   az vm deallocate \
     --name <vm-name> \
     --resource-group rg-az305-lab
   ```
4. Wait for the health probe to detect the failure (check probe interval setting).
5. Verify the application is still accessible through the load balancer:
   ```bash
   curl http://<lb-frontend-ip>
   ```
6. Check the health probe metrics to confirm one instance is now marked unhealthy.
7. Restart the VM and verify it rejoins the backend pool automatically.

### Success Criteria
- Traffic continues flowing after one VM is stopped.
- The health probe detects the failure within the configured interval.
- The restarted VM automatically re-enters the healthy pool.
- You can explain the failover timeline based on probe settings.

### Explanation
The exam tests failover behavior. Key concepts: the time to detect a failure = probe interval x number of probes (e.g., 15s interval x 2 probes = 30s detection). During this window, some requests may fail. The load balancer does not require manual intervention to remove or re-add instances. Understanding this timing is important for designing SLA-compliant solutions.

---

## Exercise 4: Trigger an On-Demand Backup and Verify in the Vault
**Difficulty:** 🟡 Intermediate
**Method:** CLI
**Estimated Time:** 20 minutes

### Objective
Trigger an on-demand backup of a VM using Azure Backup and verify the backup job completes successfully.

### Instructions
1. List Recovery Services vaults in the resource group:
   ```bash
   az backup vault list \
     --resource-group rg-az305-lab \
     --output table
   ```
2. List protected items (VMs) in the vault:
   ```bash
   az backup item list \
     --vault-name <vault-name> \
     --resource-group rg-az305-lab \
     --output table
   ```
3. Trigger an on-demand backup:
   ```bash
   az backup protection backup-now \
     --vault-name <vault-name> \
     --resource-group rg-az305-lab \
     --container-name <container-name> \
     --item-name <item-name> \
     --retain-until $(date -d "+30 days" +%Y-%m-%d) \
     --backup-management-type AzureIaasVM
   ```
4. Monitor the backup job:
   ```bash
   az backup job list \
     --vault-name <vault-name> \
     --resource-group rg-az305-lab \
     --output table \
     --query "[?properties.status=='InProgress']"
   ```
5. Once complete, list recovery points:
   ```bash
   az backup recoverypoint list \
     --vault-name <vault-name> \
     --resource-group rg-az305-lab \
     --container-name <container-name> \
     --item-name <item-name> \
     --output table
   ```

### Success Criteria
- The on-demand backup job starts and completes successfully.
- A new recovery point appears in the vault.
- You can explain the difference between scheduled vs. on-demand backups.

### Explanation
Azure Backup is tested on AZ-305 in the context of data protection strategy. The exam expects you to know that Recovery Services vaults support VMs, SQL databases, file shares, and SAP HANA. On-demand backups are useful for pre-change snapshots. The retention policy (how long recovery points are kept) is configured in the backup policy. The exam also tests cross-region restore and the difference between GRS and LRS vault storage.

---

## Exercise 5: Compare SLA of Different Availability Configurations
**Difficulty:** 🟡 Intermediate
**Method:** Conceptual / Calculator
**Estimated Time:** 15 minutes

### Objective
Calculate and compare the composite SLA for different VM deployment strategies to understand how architecture choices affect availability guarantees.

### Instructions
Calculate the composite SLA for each configuration:

1. **Single VM with Premium SSD:**
   - VM SLA: 99.9%
   - Monthly downtime budget: ?

2. **Two VMs in an Availability Set behind a Load Balancer:**
   - VM SLA: 99.95%
   - Load Balancer SLA: 99.99%
   - Composite SLA: ?

3. **Two VMs in different Availability Zones behind a Load Balancer:**
   - VM SLA: 99.99%
   - Load Balancer SLA: 99.99%
   - Composite SLA: ?

4. **Multi-region with Traffic Manager:**
   - Each region: two VMs in availability zones + LB (99.99% x 99.99%)
   - Traffic Manager SLA: 99.99%
   - Two regions in active-active: 1 - (1 - region1_SLA)^2
   - Composite SLA: ?

**Formula reminder:**
- Serial components: SLA_composite = SLA_A x SLA_B
- Parallel (redundant) components: SLA_composite = 1 - (1 - SLA_A) x (1 - SLA_B)

### Success Criteria
- You correctly calculate composite SLAs for all four configurations.
- You understand that serial dependencies multiply (reduce) SLA.
- You understand that parallel redundancy dramatically improves SLA.
- You can justify the cost/complexity trade-off of each configuration.

### Explanation
SLA calculation is a guaranteed AZ-305 exam topic. The exam provides a target SLA and expects you to choose the minimum architecture that meets it. Key insight: adding more serial components (database, cache, etc.) reduces composite SLA, so every component in the critical path matters. The exam may also test that not all services have the same SLA, and that the weakest link determines the overall availability.

---

## Exercise 6: Design a Multi-Region HA Architecture for a Web Application
**Difficulty:** 🔴 Challenge
**Method:** Conceptual
**Estimated Time:** 30 minutes

### Objective
Design a highly available, multi-region architecture for a web application that handles user authentication, product catalog, and order processing.

### Instructions
Design the architecture addressing:

1. **Front-end routing:**
   - Azure Front Door vs. Traffic Manager: which and why?
   - What routing method (priority, weighted, geographic, latency)?
   - How does health probing work at the global level?

2. **Compute tier:**
   - How are web servers deployed in each region?
   - App Service vs. VMs vs. AKS: selection criteria?
   - How many instances per region?

3. **Data tier:**
   - Azure SQL: active geo-replication vs. auto-failover groups?
   - Cosmos DB: multi-region writes vs. single-write with read replicas?
   - How do you handle data consistency during failover?

4. **State management:**
   - Session state: where is it stored? (Redis Cache, SQL, cookies)
   - How do you ensure sessions survive a regional failover?

5. **Failover process:**
   - Automatic vs. manual failover: trade-offs?
   - What is the expected RTO and RPO for each component?
   - How do you test failover without affecting production?

6. **Cost optimization:**
   - Active-active vs. active-passive: cost implications?
   - Can the secondary region run at reduced capacity?

### Success Criteria
- The design achieves 99.99% or higher composite SLA.
- Data replication strategy addresses RPO requirements.
- Failover is automated for the compute tier and semi-automated for the data tier.
- Session state survives regional failover.
- Cost is optimized using active-passive for non-critical components.

### Explanation
This is a hallmark AZ-305 design question. The exam favors Azure Front Door over Traffic Manager for web applications (Front Door provides WAF, SSL offload, caching, and faster failover). For SQL, auto-failover groups are preferred over manual geo-replication because they provide automatic failover with a DNS endpoint that does not change. For Cosmos DB, multi-region writes provide the lowest RPO (0) but highest cost. Always consider the CAP theorem implications of your consistency choices.

---

## Exercise 7: Design for Specific RPO/RTO Requirements
**Difficulty:** 🔴 Challenge
**Method:** Conceptual
**Estimated Time:** 30 minutes

### Objective
**Scenario:** An application requires 99.99% SLA, RPO of 5 minutes, and RTO of 1 hour. The application uses Azure SQL Database, Azure App Service, and Azure Storage. The budget is moderate (not unlimited). Current deployment is single-region.

Design the disaster recovery solution.

### Instructions
Address each component:

1. **Azure App Service:**
   - How do you achieve RTO < 1 hour for the compute tier?
   - Active-passive with auto-scale in the secondary region?
   - What deployment strategy ensures the secondary is always ready?

2. **Azure SQL Database:**
   - RPO of 5 minutes: which replication technology meets this?
   - Active geo-replication RPO is typically < 5 seconds. Is this sufficient?
   - Auto-failover group: what is the grace period configuration?

3. **Azure Storage:**
   - Which replication option (LRS, ZRS, GRS, GZRS, RA-GRS, RA-GZRS)?
   - What is the RPO for GRS (typically < 15 minutes)?
   - Does GRS meet the 5-minute RPO requirement?

4. **DNS and routing:**
   - How does traffic shift to the secondary region?
   - TTL considerations for DNS failover.
   - Azure Front Door vs. Traffic Manager for this scenario.

5. **Testing:**
   - How do you validate the DR plan meets RTO/RPO?
   - What is a DR drill and how often should it run?
   - How do you measure actual RPO during a failover test?

### Success Criteria
- Each component meets or exceeds the RPO of 5 minutes.
- RTO of 1 hour is achievable with the proposed architecture.
- Storage replication choice is justified (GZRS or RA-GZRS likely needed for 5-min RPO).
- A testing plan validates the DR design.
- Cost is reasonable (not over-engineered for the requirements).

### Explanation
RPO/RTO design questions are among the most common on AZ-305. Key gotcha: GRS replication for storage is asynchronous with an RPO of "typically less than 15 minutes" but with no guarantee. If the requirement is strictly 5 minutes, you may need to implement application-level replication or use a database that provides tighter RPO guarantees. The exam also tests that RTO includes time for detection + decision + execution of failover, not just the technical switch time.
