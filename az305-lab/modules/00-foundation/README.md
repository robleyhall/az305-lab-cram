# Module 00 — Foundation

Shared infrastructure that every other AZ-305 lab module depends on.

## What This Module Creates

| Resource | Name Pattern | Purpose |
|---|---|---|
| Resource Group | `az305-lab-foundation-rg-<suffix>` | Container for all foundation resources |
| Virtual Network | `az305-lab-vnet-<suffix>` | Shared 10.0.0.0/16 VNet with preallocated subnets |
| 14 Subnets | `default`, `governance`, … `GatewaySubnet` | One /24 per lab module + Azure reserved names |
| Network Security Group | `az305-lab-default-nsg-<suffix>` | Baseline rules: allow VNet inbound, deny internet inbound, allow all outbound |
| Log Analytics Workspace | `az305-lab-law-<suffix>` | Centralized logging for all modules (PerGB2018, 30-day retention) |
| Random String | 6-char suffix | Ensures globally unique resource names |

### Subnet Allocation

| Subnet | CIDR | Module |
|---|---|---|
| `default` | 10.0.0.0/24 | Foundation |
| `governance` | 10.0.1.0/24 | 01-governance |
| `identity` | 10.0.2.0/24 | 02-identity |
| `keyvault` | 10.0.3.0/24 | 03-keyvault |
| `monitoring` | 10.0.4.0/24 | 04-monitoring |
| `compute` | 10.0.5.0/24 | 09-compute |
| `storage` | 10.0.6.0/24 | 06-storage |
| `database` | 10.0.7.0/24 | 07-databases |
| `data-integration` | 10.0.8.0/24 | 08-data-integration |
| `app-architecture` | 10.0.9.0/24 | 10-app-architecture |
| `networking` | 10.0.10.0/24 | 11-networking |
| `migration` | 10.0.11.0/24 | 12-migration |
| `AzureBastionSubnet` | 10.0.250.0/24 | Azure Bastion (required name) |
| `GatewaySubnet` | 10.0.251.0/24 | VPN Gateway (required name) |

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.5
- An Azure subscription with **Contributor** access
- Azure CLI authenticated: `az login`

## Usage

```bash
# 1. Navigate to the module directory
cd az305-lab/modules/00-foundation

# 2. Copy and edit the example variables file
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars — set your preferred region, tags, etc.

# 3. Initialise Terraform (downloads providers)
terraform init

# 4. Preview the changes
terraform plan

# 5. Apply — creates all foundation resources
terraform apply

# 6. When finished studying, tear everything down
terraform destroy
```

## Inputs

| Variable | Type | Default | Description |
|---|---|---|---|
| `location` | `string` | `"eastus"` | Azure region for all resources |
| `prefix` | `string` | `"az305-lab"` | Naming prefix for resources |
| `environment` | `string` | `"lab"` | Environment label for tagging |
| `tags` | `map(string)` | Lab / CostCenter / ManagedBy | Default tags merged onto every resource |

## Outputs

| Output | Description |
|---|---|
| `resource_group_name` | Name of the foundation resource group |
| `resource_group_id` | Resource ID of the foundation resource group |
| `vnet_name` | Name of the shared virtual network |
| `vnet_id` | Resource ID of the shared virtual network |
| `subnet_ids` | Map of subnet name → subnet resource ID |
| `log_analytics_workspace_id` | Resource ID of the Log Analytics workspace |
| `log_analytics_workspace_name` | Name of the Log Analytics workspace |
| `random_suffix` | 6-char random suffix used in resource names |
| `nsg_id` | Resource ID of the default NSG |

## Dependencies

**None.** This is the root module — all other lab modules depend on it.

## Estimated Cost

| Resource | Estimated Monthly Cost |
|---|---|
| Log Analytics Workspace | ~$2–3 (PerGB2018 with minimal ingestion) |
| Virtual Network + Subnets | Free (no gateway deployed) |
| Network Security Group | Free |
| **Total** | **~$2–3/month** |

> **Tip:** Run `terraform destroy` when you're not actively studying to avoid any charges.
