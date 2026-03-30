# Module 05 — High Availability & Disaster Recovery

> **AZ-305 Exam Domain:** Design Business Continuity Solutions — **15–20% of exam weight**

## What This Module Deploys

| Resource | Name Pattern | Purpose |
|---|---|---|
| Resource Group | `az305-lab-hadr-rg-*` | Dedicated RG for HA/DR resources |
| Availability Set | `az305-lab-avset-*` | 2 FDs, 5 UDs — rack-level protection |
| 2× Linux VMs (avset) | `az305-lab-avset-vm-{0,1}-*` | Demonstrate avset placement |
| 1× Linux VM (zone) | `az305-lab-az-vm-*` | Demonstrate Availability Zone (zone 1) |
| Public Load Balancer | `az305-lab-pub-lb-*` | Standard SKU, zone-redundant, HTTP rule |
| Internal Load Balancer | `az305-lab-int-lb-*` | Standard SKU, private frontend in subnet |
| Recovery Services Vault | `az305-lab-rsv-*` | GRS, soft delete, daily VM backup policy |
| VM Backup | — | Avset VMs registered for daily backup |
| Traffic Manager | `az305-lab-tm-*` | Performance routing, global DNS LB |

**Estimated cost:** ~\$4/day (3× B1s VMs + 2 Standard LBs + Recovery Services Vault). Auto-shutdown at 22:00 UTC reduces VM costs.

## Key Exam Concepts

### Availability Sets vs Availability Zones

| | Availability Set | Availability Zone |
|---|---|---|
| **SLA** | 99.95% | 99.99% |
| **Scope** | Single datacenter (rack-level) | Cross-datacenter (region-level) |
| **Fault Domains** | Up to 3 (separate racks) | N/A (each zone = separate DC) |
| **Update Domains** | Up to 20 (rolling updates) | N/A |
| **Use when** | Legacy apps, cost-sensitive | Mission-critical, highest SLA |
| **Can combine?** | ❌ **Mutually exclusive** on same VM | ❌ |

> 💡 **Exam tip:** A single VM with Premium SSD gets 99.9% SLA. No avset or zone needed for that tier.

### Load Balancer Decision Tree

```
Need load balancing?
├── Global scope?
│   ├── HTTP/HTTPS → Azure Front Door (L7, WAF, CDN)
│   └── Any protocol → Traffic Manager (DNS-based)
└── Regional scope?
    ├── HTTP/HTTPS → Application Gateway (L7, WAF, SSL offload)
    └── TCP/UDP → Azure Load Balancer (L4, HA ports)

Standard vs Basic LB:
  Standard: zone-redundant, secure by default (NSG required), 99.99% SLA
  Basic:    no zones, open by default, no SLA — retiring Sept 2025
```

### RPO vs RTO

| | Azure Backup | Azure Site Recovery |
|---|---|---|
| **RPO** | ~24 hours (daily) | Seconds to minutes |
| **RTO** | Hours | Minutes |
| **Use case** | Data protection | Disaster recovery / failover |
| **Exam keyword** | "backup", "restore" | "disaster recovery", "failover" |

### Paired Regions

Azure pairs regions 300+ miles apart (e.g., East US ↔ West US). Recovery Services Vault with GRS automatically replicates backup data to the paired region.

## Prerequisites

- Module 00 (Foundation) deployed — provides VNet and compute subnet
- Azure CLI authenticated (`az login`)
- Terraform ≥ 1.5.0

## Deploy

```bash
cd az305-lab/modules/05-ha-dr

# Copy and edit variables
cp terraform.tfvars.example terraform.tfvars
# Fill in foundation outputs (compute_subnet_id, etc.)

terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

## Clean Up

```bash
terraform destroy
```

> ⚠️ Recovery Services Vault with soft delete retains data for 14 days after deletion. You may need to manually purge backup items before the vault can be destroyed.

## Exam Tips

1. **Availability Set + Zone = impossible on same VM.** If the exam asks for 99.99%, pick zones.
2. **Standard LB is required for zones.** Basic LB cannot work with Availability Zones.
3. **Standard LB is secure by default** — you must attach an NSG to allow traffic.
4. **Traffic Manager is DNS-only** — it doesn't proxy traffic, just returns the best endpoint IP.
5. **Front Door vs Traffic Manager:** Front Door for HTTP with WAF/CDN; Traffic Manager for any protocol.
6. **GRS is the default recommendation** for Recovery Services Vault on the exam.
7. **Azure Site Recovery** is for DR (low RPO/RTO), **Azure Backup** is for data protection.
8. **Soft delete** on vaults protects against ransomware and accidental deletion — always enable.
