# Module 06: Storage Solutions

## AZ-305 Exam Domain

**Design Data Storage Solutions — 20-25% of exam weight.**

This is one of the highest-weighted domains on the AZ-305 exam. You will see questions on storage account types, replication strategies, access tiers, lifecycle management, managed disks, security, and Data Lake Gen2.

## What This Module Creates

| Resource | Name/Pattern | Purpose |
|----------|-------------|---------|
| Resource Group | `az305-lab-storage-rg` | Isolated RG for storage resources |
| Storage Account (GPv2/GRS) | `az305-labstorage{random}` | Primary account — blob, file, queue, table |
| Blob Container | `documents` | Private access container |
| Blob Container | `public-assets` | Blob-level public access (demo) |
| Lifecycle Policy | tiered-lifecycle | Hot → Cool (30d) → Archive (90d) → Delete (365d) |
| Azure Files Share | `az305-lab-fileshare` | SMB file share (5 GB, TransactionOptimized) |
| Storage Account (Premium) | `az305-labpremblob{random}` | Premium BlockBlobStorage for low-latency |
| Storage Account (ADLS Gen2) | `az305-labdatalake{random}` | Hierarchical namespace for big data |
| Managed Disk (HDD) | `az305-lab-disk-standard` | Standard_LRS, 32 GB |
| Managed Disk (SSD) | `az305-lab-disk-premium` | Premium_LRS, 32 GB (P4) |
| Private DNS Zone | `privatelink.blob.core.windows.net` | DNS resolution for private endpoint |
| Private Endpoint | `az305-lab-storage-pe-{random}` | Private IP for blob access |
| Diagnostic Settings | `az305-lab-storage-diag` | Metrics + logs to Log Analytics |

## Estimated Cost

**~$1.50/day** breakdown:
- GPv2/GRS storage account: ~$0.05/day (minimal data)
- Premium BlockBlobStorage: ~$0.15/day (minimum charge)
- ADLS Gen2: ~$0.05/day (minimal data)
- Managed disks (32 GB Standard + 32 GB Premium): ~$0.65/day
- Private endpoint: ~$0.24/day
- Transactions/diagnostics: ~$0.10/day

> 💡 **Destroy when not studying** — `terraform destroy` to stop all charges.

## Prerequisites

1. **Module 00 (Foundation)** deployed — provides VNet, storage subnet, Log Analytics
2. Azure CLI authenticated: `az login`
3. Terraform >= 1.5.0
4. Contributor role on the subscription

## Deploy

```bash
cd az305-lab/modules/06-storage
cp terraform.tfvars.example terraform.tfvars

# Edit terraform.tfvars with values from Module 00:
#   terraform -chdir=../00-foundation output

terraform init
terraform plan
terraform apply
```

## Destroy

```bash
terraform destroy
```

## Replication Comparison Table

| Feature | LRS | ZRS | GRS | RA-GRS | GZRS | RA-GZRS |
|---------|-----|-----|-----|--------|------|---------|
| Copies | 3 | 3 | 6 | 6 | 6 | 6 |
| Zones | 1 | 3 | 1+1 | 1+1 | 3+1 | 3+1 |
| Regions | 1 | 1 | 2 | 2 | 2 | 2 |
| Read secondary | ✗ | ✗ | ✗ | ✓ | ✗ | ✓ |
| Durability (nines) | 11 | 12 | 16 | 16 | 16 | 16 |
| Premium support | ✓ | ✓ | ✗ | ✗ | ✗ | ✗ |
| Relative cost | $ | $$ | $$$ | $$$+ | $$$$ | $$$$+ |

## Managed Disk Comparison

| Disk Type | Max IOPS | Max Throughput | Single VM SLA | Use Case |
|-----------|----------|---------------|---------------|----------|
| Standard HDD | 500 | 60 MB/s | ✗ | Dev/test, backups |
| Standard SSD | 6,000 | 750 MB/s | ✗ | Web servers, light enterprise |
| Premium SSD | 20,000 | 900 MB/s | ✓ (99.9%) | Production workloads |
| Premium SSD v2 | 80,000 | 1,200 MB/s | ✓ (99.9%) | Granular IOPS provisioning |
| Ultra Disk | 160,000 | 4,000 MB/s | ✓ (99.9%) | SAP HANA, SQL, transaction-heavy |

## Key Concepts for AZ-305

### Storage Account Types
- **GPv2 (StorageV2)**: Default choice — supports all services and tiers
- **BlockBlobStorage**: Premium block/append blobs only (SSD, LRS/ZRS only)
- **FileStorage**: Premium Azure Files only (SSD, LRS/ZRS only)
- **BlobStorage**: Legacy — superseded by GPv2, avoid in new designs

### Access Tiers & Lifecycle
- **Hot** → **Cool** (30d min) → **Cold** (90d min) → **Archive** (180d min, offline)
- Lifecycle policies automate transitions based on last-modified or last-accessed date
- Archive requires rehydration: Standard (≤15 hrs) or High priority (<1 hr)

### Blob Types
- **Block Blob**: Documents, images, video (default)
- **Append Blob**: Logs, audit trails (append-only)
- **Page Blob**: VHDs, random I/O (abstracted by managed disks)

### Security Layers
1. **Network**: Firewall rules, service endpoints, private endpoints
2. **Identity**: Azure AD + RBAC (Storage Blob Data Reader/Contributor/Owner)
3. **Access**: SAS tokens (user delegation = most secure), stored access policies
4. **Encryption**: Microsoft-managed keys (default), customer-managed keys (CMK), infrastructure encryption (double)

### Data Lake Gen2
- GPv2 + `is_hns_enabled = true` = ADLS Gen2
- True directory operations (atomic rename)
- POSIX ACLs for fine-grained access
- ABFS protocol driver for Hadoop/Spark/Databricks/Synapse

### Immutable Storage (Concept)
- WORM (Write Once Read Many) for compliance
- Time-based retention or legal hold
- Once locked, cannot be shortened
- Not deployed in this lab (irreversible in production)

## Exercises

1. **Upload a blob** — Use `az storage blob upload` to the `documents` container via private endpoint
2. **Test lifecycle rules** — Upload blobs and observe tier transitions in the portal
3. **Compare access levels** — Try accessing blobs in `documents` (private) vs `public-assets` (blob access)
4. **Mount Azure Files** — Mount `az305-lab-fileshare` on a VM or local machine via SMB
5. **Query diagnostics** — Run KQL queries in Log Analytics for StorageRead/Write/Delete events
6. **Explore Data Lake** — Use Storage Explorer to browse the hierarchical namespace account
7. **Private endpoint DNS** — Verify `nslookup az305-labstorage{random}.blob.core.windows.net` resolves to private IP
8. **Failover simulation** — Review GRS replication status in the portal (Geo-replication blade)
