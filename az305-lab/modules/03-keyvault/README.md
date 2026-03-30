# Module 03 — Key Vault & Application Identity

Demonstrates Azure Key Vault for secrets management, managed identities for
passwordless authentication, RBAC-based authorization, and private endpoint
connectivity — all high-weight AZ-305 exam topics.

## AZ-305 Exam Relevance

| Topic | Weight | What This Module Covers |
|---|---|---|
| Secrets management | High | Key Vault secrets, keys, and certificates |
| Access control models | High | RBAC authorization vs access policies |
| Managed identities | High | User-assigned identity with least-privilege roles |
| Private connectivity | High | Private endpoint + Private DNS for Key Vault |
| Data protection | Medium | Soft delete, purge protection, key rotation |
| Network security | Medium | Key Vault firewall rules, VNet integration |

## Key Concepts

### RBAC vs Access Policies

Key Vault supports two authorization models. **RBAC** (used here) is the
modern recommendation because it integrates with Azure's unified RBAC system,
supports Conditional Access and PIM, and scales better than vault-level access
policies. The exam frequently tests when to choose each model.

### Managed Identity Types

| Type | Lifecycle | Use Case |
|---|---|---|
| **System-assigned** | Tied to one resource | One VM/app needs its own identity |
| **User-assigned** | Independent, shared | Multiple resources share the same permissions |

This lab creates a **user-assigned** identity so downstream modules can attach
it to VMs, App Services, or Functions without creating additional identities.

### Soft Delete & Purge Protection

- **Soft delete** (always enabled): Deleted vaults are recoverable for 7–90 days.
- **Purge protection**: Prevents permanent deletion during the retention window.
- Lab uses 7-day retention and no purge protection for easy teardown.
- Production should use 90 days with purge protection enabled.

### Private Endpoint Pattern

The three-piece pattern tested on AZ-305:
1. **Private Endpoint** — NIC with private IP in your subnet
2. **Private DNS Zone** — resolves `*.vault.azure.net` → private IP
3. **VNet Link** — connects DNS zone to VNet for resolution

## What This Module Creates

| Resource | Name Pattern | Purpose |
|---|---|---|
| Resource Group | `az305-lab-keyvault-rg-<suffix>` | Container for all Key Vault resources |
| User-Assigned Managed Identity | `az305-lab-managed-id-<suffix>` | Shared identity for downstream modules |
| Key Vault | `az305-lab-kv-<suffix>` | Secrets, keys, and certificates store |
| Key Vault Secret | `db-connection-string` | Sample database connection string |
| Key Vault Key | `az305-lab-encryption-key` | RSA-2048 key for encryption demos |
| Key Vault Certificate | `az305-lab-tls-demo` | Self-signed cert for TLS demos |
| Role Assignments | 3 assignments | Admin (you) + Secrets User + Crypto User (identity) |
| Private Endpoint | `az305-lab-kv-pe-<suffix>` | Private connectivity to Key Vault |
| Private DNS Zone | `privatelink.vaultcore.azure.net` | DNS resolution for private endpoint |
| Diagnostic Setting | `az305-lab-kv-diag` | Audit logs → Log Analytics |

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.5
- An Azure subscription with **Owner** access (needed for role assignments)
- Azure CLI authenticated: `az login`
- **Module 00 (Foundation)** deployed — provides VNet, subnets, Log Analytics

## Usage

```bash
# 1. Navigate to the module directory
cd az305-lab/modules/03-keyvault

# 2. Copy and customise variables
cp terraform.tfvars.example terraform.tfvars
# Fill in the foundation module outputs (vnet_id, subnet_id, etc.)

# 3. Initialise Terraform
terraform init

# 4. Preview changes
terraform plan

# 5. Deploy
terraform apply

# 6. Verify — list vault contents
az keyvault secret list --vault-name $(terraform output -raw key_vault_name)
az keyvault key list    --vault-name $(terraform output -raw key_vault_name)

# 7. Test managed identity access (from an Azure VM with the identity attached)
#    curl "http://169.254.169.254/metadata/identity/oauth2/token?resource=https://vault.azure.net&client_id=$(terraform output -raw managed_identity_client_id)" -H "Metadata: true"

# 8. Clean up
terraform destroy
```

## Inputs

| Variable | Type | Default | Description |
|---|---|---|---|
| `location` | `string` | `"eastus"` | Azure region |
| `prefix` | `string` | `"az305-lab"` | Naming prefix (keep short — KV has 24-char limit) |
| `foundation_resource_group_name` | `string` | — | Foundation resource group name |
| `vnet_id` | `string` | — | Shared VNet resource ID |
| `keyvault_subnet_id` | `string` | — | Key Vault subnet resource ID |
| `log_analytics_workspace_id` | `string` | — | Log Analytics workspace resource ID |
| `tags` | `map(string)` | Lab defaults | Tags merged onto every resource |

## Outputs

| Output | Description |
|---|---|
| `resource_group_name` | Name of the Key Vault resource group |
| `key_vault_id` | Resource ID of the Key Vault |
| `key_vault_name` | Globally unique Key Vault name |
| `key_vault_uri` | Key Vault URI (https://…vault.azure.net/) |
| `managed_identity_id` | Resource ID of the managed identity |
| `managed_identity_principal_id` | Principal (object) ID for role assignments |
| `managed_identity_client_id` | Client ID for app configuration |
| `private_endpoint_ip` | Private IP of the Key Vault endpoint |

## Dependencies

| Module | What It Provides |
|---|---|
| **00-foundation** | VNet, keyvault subnet, Log Analytics workspace |

## Estimated Cost

| Resource | Estimated Daily Cost |
|---|---|
| Key Vault (standard, low usage) | ~$0.03 |
| Private Endpoint | ~$0.24 |
| Managed Identity | Free |
| Role Assignments | Free |
| **Total** | **~$0.50/day** |

> **Tip:** Run `terraform destroy` when not actively studying to stop all charges.

## Study Questions

1. When should you use RBAC authorization vs access policies for Key Vault?
2. What is the difference between system-assigned and user-assigned managed identities?
3. Why would you enable purge protection in production but disable it in a lab?
4. What three components make up the private endpoint pattern?
5. When should you store a value as a Key Vault secret vs a key vs a certificate?
6. How does key rotation work with Customer Managed Keys (CMK)?
