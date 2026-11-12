# AZ-305 Lab — Cleanup & Teardown Guide

> **Important:** Follow this guide to completely remove all lab resources and stop incurring charges.

---

## 1. Pre-Cleanup Checklist

Before destroying anything, verify:

- [ ] **No production data** exists in any lab resource group
- [ ] **Export exercise results** you want to keep (screenshots, query outputs, architecture diagrams)
- [ ] **Note Key Vault names** — soft-delete means vaults persist after deletion (90-day default retention)
- [ ] **Check for backup items** in Recovery Services Vaults — these must be removed before vault deletion
- [ ] **Download any Terraform state** you want to archive: `terraform state pull > state-backup.json`

---

## 2. Automated Cleanup

The fastest path — destroys all modules in the correct dependency order:

```bash
./scripts/destroy-all.sh
```

This script will:

1. Iterate modules in reverse order (12 → 00)
2. Run `terraform destroy -auto-approve` in each
3. Report success/failure for each module
4. Prompt before purging soft-deleted Key Vaults

---

## 3. Manual Cleanup Order

If automated cleanup fails or you need to destroy selectively, work in **reverse module order** to respect resource dependencies:

```bash
# Module 12 — Migration
cd modules/12-migration && terraform destroy -auto-approve && cd ../..

# Module 11 — Networking
cd modules/11-networking && terraform destroy -auto-approve && cd ../..

# Module 10 — App Architecture
cd modules/10-app-architecture && terraform destroy -auto-approve && cd ../..

# Module 09 — Compute
cd modules/09-compute && terraform destroy -auto-approve && cd ../..

# Module 08 — Data Integration
cd modules/08-data-integration && terraform destroy -auto-approve && cd ../..

# Module 07 — Databases
cd modules/07-databases && terraform destroy -auto-approve && cd ../..

# Module 06 — Storage
cd modules/06-storage && terraform destroy -auto-approve && cd ../..

# Module 05 — HA/DR
cd modules/05-ha-dr && terraform destroy -auto-approve && cd ../..

# Module 04 — Monitoring
cd modules/04-monitoring && terraform destroy -auto-approve && cd ../..

# Module 03 — Key Vault
cd modules/03-keyvault && terraform destroy -auto-approve && cd ../..

# Module 02 — Identity
cd modules/02-identity && terraform destroy -auto-approve && cd ../..

# Module 01 — Governance
cd modules/01-governance && terraform destroy -auto-approve && cd ../..

# Module 00 — Foundation (last — other modules depend on it)
cd modules/00-foundation && terraform destroy -auto-approve && cd ../..
```

> **Why reverse order?** Later modules reference resources from earlier modules (VNet, Log Analytics, Key Vault). Destroying foundation first would cause dependency errors.

---

## 4. Post-Cleanup Verification

After destroying all modules, verify nothing was left behind:

```bash
# Check for remaining resource groups with the lab prefix
az group list --query "[?starts_with(name, 'az305-lab')]" -o table
```

```bash
# Check for soft-deleted Key Vaults
az keyvault list-deleted -o table
```

```bash
# Purge soft-deleted Key Vaults (removes them permanently)
az keyvault purge --name <vault-name>
```

```bash
# Check for orphaned resources tagged with the lab tag
az resource list --query "[?tags.Lab == 'AZ-305']" -o table
```

```bash
# Verify no recent charges are accruing
az consumption usage list \
  --start-date "$(date -u -v-1d +%Y-%m-%d)" \
  --end-date "$(date -u +%Y-%m-%d)" \
  -o table
```

```bash
# Check for orphaned managed disks
az disk list --query "[?starts_with(resourceGroup, 'az305-lab')]" -o table
```

```bash
# Check for orphaned public IPs
az network public-ip list --query "[?starts_with(resourceGroup, 'az305-lab')]" -o table
```

---

## 5. Residual Costs to Watch

Even after `terraform destroy`, these resources may continue to incur charges:

| Resource | Why It Persists | How to Resolve |
|----------|----------------|----------------|
| Soft-deleted Key Vaults | 90-day purge protection by default | `az keyvault purge --name <name>` |
| Storage accounts with delete retention | Blob soft-delete / versioning retention | Disable retention, then delete |
| Public IP addresses | Charged even when unattached to a resource | `az network public-ip delete` |
| Recovery Services Vault | May retain backup data / soft-deleted items | Remove all backup items first |
| Managed disks | Charged for allocated capacity until deleted | `az disk delete` |
| DNS zones | ~$0.50/month per zone | `az network dns zone delete` |
| Log Analytics workspace | Data retention charges after deletion (30-day recovery) | Wait for retention period to expire |

---

## 6. Azure Cost Management Verification

Confirm charges have stopped via the Azure Portal:

1. Navigate to **Cost Management + Billing → Cost Analysis**
2. Set date range to cover your entire lab period
3. Filter by tag: **CostCenter = CertStudy**
4. Group by **Resource Group** to identify any remaining charges
5. Verify all charges stop within **24–48 hours** of cleanup

> **Note:** Azure billing data has a ~24-hour delay. Don't panic if you see charges the day after cleanup — check again the next day.

### Remove Budget Alert

If you set up a budget alert during the lab, clean it up:

```bash
az consumption budget delete --budget-name "AZ305-Lab-Budget"
```

---

## 7. Troubleshooting

### "Resource group has resources that cannot be deleted"

**Causes:** Resource locks, active backup items, or soft-delete protection.

```bash
# List and remove resource locks
az lock list --resource-group <rg-name> -o table
az lock delete --name <lock-name> --resource-group <rg-name>
```

### "Key Vault cannot be deleted"

**Cause:** Purge protection is enabled (cannot be disabled once set).

- If purge protection is on, you must **wait for the retention period** (7–90 days)
- The vault will not incur charges after soft-deletion, only during retention if accessed

```bash
# Check purge protection status
az keyvault show --name <vault-name> --query "properties.enablePurgeProtection"

# If purge protection is off, purge immediately
az keyvault purge --name <vault-name>
```

### "Recovery Services Vault cannot be deleted"

**Cause:** Vault still contains backup items or soft-deleted items.

```bash
# List backup items
az backup item list --vault-name <vault-name> --resource-group <rg-name> -o table

# Disable soft-delete on the vault
az backup vault backup-properties set \
  --name <vault-name> \
  --resource-group <rg-name> \
  --soft-delete-feature-state Disable

# Stop and delete each backup item
az backup protection disable \
  --item-name <item-name> \
  --vault-name <vault-name> \
  --resource-group <rg-name> \
  --container-name <container-name> \
  --backup-management-type AzureIaasVM \
  --delete-backup-data true --yes
```

### "Terraform state is out of sync"

**Cause:** Resources were deleted manually or by another process.

```bash
# Refresh state to match actual Azure resources
terraform refresh

# If resources are gone, remove them from state
terraform state rm <resource_address>

# Then destroy remaining resources
terraform destroy -auto-approve
```

### "Subscription still shows charges days after cleanup"

1. Check for resources in **other regions** (Terraform may have created some outside East US)
2. Look for **Entra ID P2 licenses** if enabled during Module 02
3. Check **Azure Advisor** for cost recommendations on remaining resources
4. Contact Azure Support if charges persist after 72 hours with no visible resources

---

## Nuclear Option

If all else fails, delete every resource group with the lab prefix directly:

```bash
# ⚠️ DANGER: This bypasses Terraform state entirely
for rg in $(az group list --query "[?starts_with(name, 'az305-lab')].name" -o tsv); do
  echo "Deleting resource group: $rg"
  az group delete --name "$rg" --yes --no-wait
done
```

> **Warning:** After using this, your Terraform state files will be out of sync. Delete the `.terraform` directories and `terraform.tfstate` files from each module if you plan to redeploy later.
