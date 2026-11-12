# Module 02 — Identity & Access

> **Deployability:** 🟡 Partially deployable — core resources work on any tenant; Conditional Access requires Entra ID P1+; PIM and Access Reviews require P2 (concept-only).

## Estimated Cost

**~$0.00–$0.10/day.** Entra ID security groups, app registrations, service principals, and RBAC assignments are **free**. The user-assigned managed identity is also free. Conditional Access policies incur no extra cost but require P1+ licensing on the tenant. Log Analytics ingestion for Entra ID logs is minimal at lab scale.

## AZ-305 Exam Relevance

This module covers topics from the **"Design identity, governance, and monitoring solutions"** exam domain (~25–30% of the exam):

| Topic | Weight | Covered Here |
|---|---|---|
| Authentication & authorization | High | ✅ Groups, RBAC, App Registrations |
| Conditional Access | High | ✅ MFA policy (P1+ gated) |
| Managed Identity vs Service Principal | High | ✅ Both deployed + compared |
| Azure AD Connect / Cloud Sync | Medium | 📝 Comments only (requires on-prem) |
| B2B vs B2C | Medium | 📝 Comments only (concept) |
| PIM (just-in-time access) | High | 📝 Comments only (requires P2) |
| Access Reviews | Medium | 📝 Comments only (requires P2) |
| Password Hash Sync / PTA / Federation | Medium | 📝 Comments only (requires on-prem) |

## What Gets Deployed

| Resource | Type | Free Tier? |
|---|---|---|
| Resource Group | `azurerm_resource_group` | ✅ Free |
| `az305-lab-admins` security group | `azuread_group` | ✅ Free |
| `az305-lab-developers` security group | `azuread_group` | ✅ Free |
| `az305-lab-readers` security group | `azuread_group` | ✅ Free |
| Lab app registration | `azuread_application` | ✅ Free |
| Lab service principal | `azuread_service_principal` | ✅ Free |
| Reader role assignment (readers → RG) | `azurerm_role_assignment` | ✅ Free |
| Contributor role assignment (devs → RG) | `azurerm_role_assignment` | ✅ Free |
| User-assigned managed identity | `azurerm_user_assigned_identity` | ✅ Free |
| Entra ID diagnostic settings | `azurerm_monitor_aad_diagnostic_setting` | ✅ Free* |
| Conditional Access policy (MFA for admins) | `azuread_conditional_access_policy` | ⚠️ Requires P1+ |

\* Log Analytics ingestion costs apply per the foundation module's workspace pricing.

## Prerequisites

1. **Foundation module deployed** — you need the resource group name and Log Analytics workspace ID.
2. **Entra ID permissions** — the deploying user/SP needs:
   - `Application Administrator` or `Global Administrator` (for app registrations)
   - `Groups Administrator` (for security groups)
   - `Security Administrator` (for diagnostic settings and Conditional Access)
3. **Terraform providers** — `azurerm ~> 4.0`, `azuread ~> 3.0`, `random ~> 3.6`

## Deploy

```bash
# 1. Get foundation outputs
cd ../00-foundation
terraform output

# 2. Configure this module
cd ../02-identity
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your foundation values

# 3. Deploy
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

## Tear Down

```bash
terraform destroy
```

This safely removes all identity objects. Entra ID groups, app registrations, and role assignments are deleted. No orphaned resources.

## Key Concepts for the Exam

### Authentication Methods (know the trade-offs)

| Method | Passwords in Cloud? | On-prem Dependency | Complexity |
|---|---|---|---|
| Password Hash Sync (PHS) | Hashes of hashes | Low (sync agent) | ⭐ Simplest |
| Pass-Through Auth (PTA) | No | High (on-prem agents) | ⭐⭐ |
| Federation (AD FS) | No | Very High (AD FS farm) | ⭐⭐⭐ |

**Default recommendation:** PHS + Seamless SSO unless compliance mandates otherwise.

### Conditional Access Evaluation

```
Sign-in request
  ├── Evaluate ALL policies in parallel
  ├── Any BLOCK policy matches? → ACCESS DENIED
  ├── Collect all GRANT controls from matching policies
  └── All grant controls satisfied? → ACCESS GRANTED
                                    → ACCESS DENIED
```

### Identity Decision Flowchart

```
Need Azure resource → Azure resource auth?
  └── YES → Use Managed Identity (system-assigned unless sharing needed)
Need external app/CI → Azure auth?
  └── YES → Use Service Principal (backed by App Registration)
Need user sign-in?
  └── Internal users → Entra ID (with Conditional Access)
  └── Partner users  → B2B guest invitations
  └── Consumer users → Azure AD B2C
```

## File Inventory

| File | Purpose |
|---|---|
| `main.tf` | All resources + extensive AZ-305 exam concept comments |
| `variables.tf` | Input variables with defaults |
| `outputs.tf` | Resource IDs consumed by downstream modules |
| `terraform.tfvars.example` | Copy to `terraform.tfvars` and fill in |
| `README.md` | This file |
