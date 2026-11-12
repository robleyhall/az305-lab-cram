# Module 06: Storage Solutions — Exercises

## Exercise 1: Upload a Blob and Verify Replication Settings
**Difficulty:** 🟢 Guided
**Method:** CLI
**Estimated Time:** 10 minutes

### Objective
Upload a file to Azure Blob Storage and inspect the storage account's replication configuration to understand data redundancy.

### Instructions
1. List storage accounts in the lab resource group:
   ```bash
   az storage account list \
     --resource-group rg-az305-lab \
     --output table \
     --query "[].{Name:name, SKU:sku.name, Kind:kind, Location:location}"
   ```
2. Check the replication setting of a storage account:
   ```bash
   az storage account show \
     --name <storage-account-name> \
     --output json | jq '{replication: .sku.name, accessTier: .accessTier, kind: .kind}'
   ```
3. List containers in the storage account:
   ```bash
   az storage container list \
     --account-name <storage-account-name> \
     --auth-mode login \
     --output table
   ```
4. Upload a test file:
   ```bash
   echo "AZ-305 Lab Test File" > testfile.txt
   az storage blob upload \
     --account-name <storage-account-name> \
     --container-name <container-name> \
     --name testfile.txt \
     --file testfile.txt \
     --auth-mode login
   ```
5. Verify the upload and check blob properties:
   ```bash
   az storage blob show \
     --account-name <storage-account-name> \
     --container-name <container-name> \
     --name testfile.txt \
     --auth-mode login \
     --output json | jq '{blobType: .properties.blobType, tier: .properties.blobTier, contentLength: .properties.contentLength}'
   ```

### Success Criteria
- You can identify the replication type (LRS, ZRS, GRS, RA-GRS, GZRS, RA-GZRS).
- You successfully uploaded a blob and verified its properties.
- You understand what each replication option means for durability and availability.

### Explanation
AZ-305 tests storage redundancy decisions heavily. Key facts: LRS = 3 copies in one datacenter (99.999999999% durability). ZRS = 3 copies across availability zones. GRS = LRS + async copy to paired region. RA-GRS = GRS + read access to secondary. GZRS = ZRS + async copy to paired region. The exam expects you to choose based on requirements: cross-region DR needs GRS/GZRS, read access during outage needs RA-GRS/RA-GZRS.

---

## Exercise 2: Check Storage Account Firewall Rules
**Difficulty:** 🟢 Guided
**Method:** CLI
**Estimated Time:** 10 minutes

### Objective
Inspect the network security configuration of a storage account to understand how access is controlled at the network level.

### Instructions
1. View the network rules for the storage account:
   ```bash
   az storage account show \
     --name <storage-account-name> \
     --output json | jq '{defaultAction: .networkRuleSet.defaultAction, virtualNetworkRules: .networkRuleSet.virtualNetworkRules, ipRules: .networkRuleSet.ipRules, bypass: .networkRuleSet.bypass}'
   ```
2. Check if the default action is `Allow` (public) or `Deny` (restricted):
   - `Allow` = all networks can access (less secure).
   - `Deny` = only explicitly allowed networks/IPs can access.
3. List any VNet rules (service endpoints):
   ```bash
   az storage account network-rule list \
     --account-name <storage-account-name> \
     --output table
   ```
4. Check if private endpoints are configured:
   ```bash
   az network private-endpoint-connection list \
     --id "/subscriptions/<sub-id>/resourceGroups/rg-az305-lab/providers/Microsoft.Storage/storageAccounts/<storage-account-name>" \
     --output table
   ```
5. Note the `bypass` setting (typically includes `AzureServices` to allow trusted Azure services).

### Success Criteria
- You can identify whether the storage account allows public access or is restricted.
- You know which VNets/IPs are allowed.
- You understand the `bypass` setting and why `AzureServices` is commonly allowed.

### Explanation
Storage account network security is a frequent AZ-305 topic. The exam tests the difference between service endpoints (VNet rules) and private endpoints. Service endpoints route traffic over the Microsoft backbone but the storage account still has a public IP. Private endpoints assign a private IP from your VNet. The exam generally favors private endpoints for production workloads. The `AzureServices` bypass allows trusted services (Backup, Monitor, etc.) to access storage even when the firewall is enabled.

---

## Exercise 3: Create a SAS Token with Specific Permissions and Test Access
**Difficulty:** 🟡 Intermediate
**Method:** CLI
**Estimated Time:** 20 minutes

### Objective
Generate a Shared Access Signature (SAS) token with specific permissions, time limits, and IP restrictions, then test access using the token.

### Instructions
1. Generate a service SAS token for a specific blob container with read-only access:
   ```bash
   az storage container generate-sas \
     --account-name <storage-account-name> \
     --name <container-name> \
     --permissions r \
     --expiry $(date -u -d "+1 hour" +%Y-%m-%dT%H:%MZ) \
     --auth-mode login \
     --as-user \
     --output tsv
   ```
2. Test the SAS token by listing blobs:
   ```bash
   az storage blob list \
     --account-name <storage-account-name> \
     --container-name <container-name> \
     --sas-token "<sas-token>" \
     --output table
   ```
3. Try to upload a blob using the read-only SAS (it should fail):
   ```bash
   az storage blob upload \
     --account-name <storage-account-name> \
     --container-name <container-name> \
     --name unauthorized-upload.txt \
     --file testfile.txt \
     --sas-token "<sas-token>"
   ```
4. Generate an account SAS with broader permissions and compare:
   ```bash
   az storage account generate-sas \
     --account-name <storage-account-name> \
     --permissions rwdlacup \
     --services b \
     --resource-types co \
     --expiry $(date -u -d "+1 hour" +%Y-%m-%dT%H:%MZ) \
     --output tsv
   ```
5. Understand the SAS hierarchy: Account SAS > Service SAS > User Delegation SAS.

### Success Criteria
- The SAS token grants only read access (write attempts fail).
- The SAS token expires after the configured time.
- You understand the difference between account SAS, service SAS, and user delegation SAS.

### Explanation
The exam tests SAS token types and when to use each. User delegation SAS (signed with Entra ID credentials) is the most secure and recommended. Service SAS is signed with the account key and scoped to a single service. Account SAS is signed with the account key and can span services. The exam expects you to recommend user delegation SAS for applications and stored access policies for managing SAS lifecycle. Always set the shortest practical expiry time.

---

## Exercise 4: Manually Move a Blob Between Access Tiers and Observe
**Difficulty:** 🟡 Intermediate
**Method:** CLI
**Estimated Time:** 15 minutes

### Objective
Move a blob between Hot, Cool, and Archive tiers to understand the tiering mechanism and its cost and access implications.

### Instructions
1. Check the current tier of an existing blob:
   ```bash
   az storage blob show \
     --account-name <storage-account-name> \
     --container-name <container-name> \
     --name testfile.txt \
     --auth-mode login \
     --output json | jq '{blobTier: .properties.blobTier, lastModified: .properties.lastModified}'
   ```
2. Move the blob to the Cool tier:
   ```bash
   az storage blob set-tier \
     --account-name <storage-account-name> \
     --container-name <container-name> \
     --name testfile.txt \
     --tier Cool \
     --auth-mode login
   ```
3. Verify the tier changed:
   ```bash
   az storage blob show \
     --account-name <storage-account-name> \
     --container-name <container-name> \
     --name testfile.txt \
     --auth-mode login \
     --query "properties.blobTier"
   ```
4. Move the blob to Archive tier:
   ```bash
   az storage blob set-tier \
     --account-name <storage-account-name> \
     --container-name <container-name> \
     --name testfile.txt \
     --tier Archive \
     --auth-mode login
   ```
5. Try to read the archived blob (it should require rehydration):
   ```bash
   az storage blob download \
     --account-name <storage-account-name> \
     --container-name <container-name> \
     --name testfile.txt \
     --file downloaded.txt \
     --auth-mode login
   ```
6. Initiate rehydration by setting the tier back to Hot or Cool.

### Success Criteria
- You can change blob tiers and verify the change.
- You understand that Archive blobs are offline and require rehydration (hours to complete).
- You know that tier changes may incur early deletion penalties (Cool: 30 days, Archive: 180 days).

### Explanation
Blob tiering is heavily tested on AZ-305. Hot = frequent access, highest storage cost, lowest access cost. Cool = infrequent access (30+ days), lower storage cost, higher access cost. Cold = rare access (90+ days). Archive = offline, lowest storage cost, highest access cost, rehydration takes hours. The exam tests lifecycle management policies that automatically tier blobs based on last access or modification time.

---

## Exercise 5: Compare Storage Costs Across Replication Options
**Difficulty:** 🟡 Intermediate
**Method:** Portal / Calculator
**Estimated Time:** 20 minutes

### Objective
Use the Azure Pricing Calculator to compare the monthly cost of different storage replication and tier options for a realistic workload.

### Instructions
Calculate monthly costs for the following scenario:
- 10 TB of data
- 100,000 read transactions/month
- 10,000 write transactions/month
- Region: East US

Compare these configurations:

| Configuration | Replication | Access Tier |
|---|---|---|
| A | LRS | Hot |
| B | ZRS | Hot |
| C | GRS | Hot |
| D | RA-GZRS | Hot |
| E | LRS | Cool |
| F | GRS | Archive |

For each configuration, note:
1. Storage cost per GB/month.
2. Transaction costs.
3. Data retrieval costs (especially for Cool and Archive).
4. Total monthly cost.

### Success Criteria
- You have a comparison table showing costs for all six configurations.
- You can explain why Archive storage is cheapest for storage but most expensive for retrieval.
- You can recommend the right configuration based on access patterns and durability requirements.
- You understand the cost difference between LRS and GRS is roughly 2x.

### Explanation
Cost optimization questions are common on AZ-305. The exam presents scenarios with specific access patterns and expects you to choose the most cost-effective storage option. Key insight: the cheapest storage tier is not always the cheapest total cost if you have frequent read operations. Cool tier saves on storage but adds retrieval costs. Archive tier is only cost-effective for truly rarely accessed data where rehydration delay is acceptable.

---

## Exercise 6: Design a Storage Strategy for Compliance Requirements
**Difficulty:** 🔴 Challenge
**Method:** Conceptual
**Estimated Time:** 30 minutes

### Objective
Design a comprehensive storage strategy for a financial services organization with the following requirements: 7-year retention for financial records, immutable storage for audit trails, encryption with customer-managed keys, and geographic redundancy for disaster recovery.

### Instructions
Design the solution addressing:

1. **Immutable storage:**
   - What is an immutable blob storage policy?
   - Time-based retention vs. legal hold: when to use each?
   - Can immutable blobs be deleted before the retention period expires?

2. **Encryption:**
   - Microsoft-managed keys vs. customer-managed keys (CMK): trade-offs?
   - Where should the CMK be stored? (Key Vault)
   - Does double encryption (infrastructure encryption) add value here?

3. **Lifecycle management:**
   - Design a lifecycle policy: Hot for 30 days, Cool for 1 year, Archive for remaining 6 years.
   - How does lifecycle management interact with immutable policies?
   - What happens when the retention period expires?

4. **Replication and DR:**
   - Which replication type for financial records? (RA-GZRS recommended)
   - How do you access data in the secondary region during an outage?
   - What is the failover process for storage accounts?

5. **Access control:**
   - How do you ensure only authorized personnel can modify immutability policies?
   - What RBAC roles control storage management vs. data access?
   - How do you audit all access to financial records?

### Success Criteria
- Immutable storage with time-based retention is configured for 7 years.
- CMK encryption is enabled using Key Vault.
- Lifecycle management moves data through tiers cost-effectively.
- RA-GZRS provides geographic redundancy with read access during outages.
- RBAC separates management plane and data plane access.

### Explanation
This combines multiple AZ-305 storage concepts. The exam tests immutable storage for regulatory compliance (WORM: Write Once, Read Many). Key trap: once a time-based retention policy is locked, it cannot be shortened, only extended. Legal holds can be applied and removed independently of retention policies. The exam also tests that immutability policies and lifecycle management can coexist, data tiers down automatically, and immutability follows the blob through tier changes.

---

## Exercise 7: Design a Data Tiering Strategy for Large-Scale Data
**Difficulty:** 🔴 Challenge
**Method:** Conceptual
**Estimated Time:** 25 minutes

### Objective
**Scenario:** You need to store 50TB of data that is accessed daily for the first month, then rarely accessed for 11 months, then must be retained for 7 years for compliance. Ingestion rate is 500GB/day. Cost must be minimized while ensuring data is retrievable within 24 hours when needed.

Design the tiering strategy.

### Instructions
Address the following:

1. **Storage account configuration:**
   - Account kind: StorageV2 (general purpose v2) for tiering support.
   - Default access tier: Hot (for incoming data).
   - Replication: what level of redundancy?

2. **Lifecycle management rules:**
   - Rule 1: Move blobs to Cool tier after 30 days since last modification.
   - Rule 2: Move blobs to Cold tier after 90 days.
   - Rule 3: Move blobs to Archive tier after 365 days.
   - Rule 4: Delete blobs after 2,555 days (7 years).
   - How do you handle the 24-hour retrieval requirement for archived data?

3. **Cost estimation:**
   - Calculate approximate monthly cost for steady state (50TB total, mixed tiers).
   - Compare with storing everything in Hot tier.
   - What is the break-even point for tiering vs. flat storage?

4. **Retrieval strategy for archived data:**
   - Standard rehydration (up to 15 hours) vs. High Priority (< 1 hour).
   - Cost difference between standard and high priority rehydration.
   - Can you set up automated rehydration?

5. **Monitoring:**
   - How do you track storage costs by tier?
   - How do you monitor lifecycle management policy execution?

### Success Criteria
- Lifecycle management automatically tiers data without manual intervention.
- Archive tier with standard rehydration meets the 24-hour retrieval SLA.
- Total cost is significantly lower than storing all data in Hot tier.
- The design accounts for early deletion fees when data moves between tiers.
- Monitoring tracks cost and policy execution.

### Explanation
This is a signature AZ-305 cost optimization question. The exam expects you to know lifecycle management rules and their behavior. Key detail: lifecycle management runs once per day, so tier transitions are not instant. Early deletion fees apply when data is moved out of Cool (30 days) or Archive (180 days) before the minimum retention period. For 50TB with the described access pattern, tiering can reduce costs by 60-80% compared to keeping everything in Hot tier.
