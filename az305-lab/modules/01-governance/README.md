# Module 01: Governance & Compliance

## AZ-305 Exam Domain

**Design identity, governance, and monitoring solutions — 25-30% of exam weight.**

This module covers the governance pillar of Azure architecture design. The AZ-305 exam tests your ability to recommend the right governance constructs for a given scenario, not just knowing what they do.

## What This Module Creates

| Resource | Type | Purpose |
|----------|------|---------|
| Resource Group | `az305-lab-governance-rg` | Isolated RG for governance resources |
| Management Group | `az305-lab-lab-mg` | Demonstrates hierarchy (optional) |
| Custom Policy — Require CostCenter Tag | `azurerm_policy_definition` | Tag enforcement pattern |
| Custom Policy — Restrict VM SKUs | `azurerm_policy_definition` | Cost control pattern |
| Policy Assignment — CostCenter Tag | `azurerm_resource_group_policy_assignment` | Assigned in audit mode |
| Policy Assignment — Allowed Locations | `azurerm_resource_group_policy_assignment` | Built-in policy (eastus only) |
| Policy Assignment — Security Benchmark | `azurerm_resource_group_policy_assignment` | Built-in initiative in audit mode |
| Custom RBAC Role — Lab Reader Plus | `azurerm_role_definition` | Reader + VM restart permissions |
| Resource Lock | `azurerm_management_lock` | CanNotDelete on governance RG |

## Estimated Cost

**~$0.10/day** — Policy definitions, role definitions, and resource locks are free Azure metadata objects. The only billable resource is the resource group itself (negligible cost). Management groups are also free.

## Prerequisites

1. Module 00 (Foundation) deployed — you need its resource group name
2. Azure CLI authenticated: `az login`
3. Terraform >= 1.5.0 installed
4. Sufficient permissions: Contributor + User Access Administrator (or Owner)
5. For management groups: `Microsoft.Management/managementGroups/write` permission

## Deploy

```bash
# 1. Get foundation resource group name
cd ../00-foundation
FOUNDATION_RG=$(terraform output -raw resource_group_name)

# 2. Deploy governance module
cd ../01-governance
cp terraform.tfvars.example terraform.tfvars

# Edit terraform.tfvars — set foundation_resource_group_name to $FOUNDATION_RG
# Or pass it directly:
terraform init
terraform plan -var="foundation_resource_group_name=$FOUNDATION_RG"
terraform apply -var="foundation_resource_group_name=$FOUNDATION_RG"
```

### If management group creation fails

Some subscriptions restrict management group creation. Disable it:

```bash
terraform apply -var="foundation_resource_group_name=$FOUNDATION_RG" \
                -var="create_management_group=false"
```

## Destroy

⚠️ **Important:** This module includes a resource lock. You must remove it before destroying:

```bash
# Option 1: Targeted destroy (recommended)
terraform destroy -target=azurerm_management_lock.governance_rg_lock \
  -var="foundation_resource_group_name=$FOUNDATION_RG"
terraform destroy -var="foundation_resource_group_name=$FOUNDATION_RG"

# Option 2: Remove lock via Azure CLI first
az lock delete --name az305-lab-governance-rg-nodelete \
  --resource-group az305-lab-governance-rg
terraform destroy -var="foundation_resource_group_name=$FOUNDATION_RG"
```

## Key Concepts for AZ-305

### Azure Policy

- **Policy vs. Initiative**: A policy is a single rule; an initiative (policy set) groups multiple policies for cohesive compliance.
- **Effects** (in evaluation order): Disabled → Append/Modify → Deny → Audit → AuditIfNotExists → DeployIfNotExists.
- **Inheritance**: Policies assigned at management group → inherited by subscriptions → inherited by resource groups. Narrowest scope wins.
- **Exclusions**: You can exempt specific child scopes from inherited policies.
- **Remediation**: `DeployIfNotExists` and `Modify` effects can auto-remediate existing non-compliant resources via remediation tasks.

### Management Groups

- Provide governance scope above subscriptions.
- Up to 6 levels of depth (excluding root and subscription level).
- Support 10,000 management groups per tenant.
- Policy and RBAC assignments inherit downward.

### RBAC (Role-Based Access Control)

- **Model**: Security Principal + Role Definition + Scope = Role Assignment.
- **Cumulative**: Permissions from multiple assignments are unioned.
- **Deny Assignments**: Only exception to cumulative model (from Blueprints/system).
- **Custom Roles**: Fill gaps when built-in roles don't match your requirements.
- **PIM (Privileged Identity Management)**: Just-in-time role activation, requires Entra ID P2. Cannot be configured via Terraform.

### Resource Locks

- **CanNotDelete**: Prevents deletion, allows modification.
- **ReadOnly**: Prevents both — use with caution (breaks Terraform apply).
- Locks inherit from parent scopes. Even Owners must remove locks before deleting.

### Blueprints (Deprecated)

Replaced by Terraform/Bicep + Azure Policy + Deployment Stacks. Know for legacy exam questions.

## Exercises

After deploying this module, try these hands-on exercises:

1. **Policy Compliance Check**: Navigate to Azure Portal → Policy → Compliance. Find the governance RG and review which resources are non-compliant with the CostCenter tag policy.

2. **Test the VM SKU Policy**: Try deploying a VM with a restricted SKU (e.g., `Standard_E4s_v5`) into the governance RG. Observe the deny message.

3. **Custom Role Inspection**: In Portal → Subscriptions → Access Control (IAM) → Roles, search for "Lab Reader Plus". Review its permissions vs. the built-in "Reader" role.

4. **Lock Testing**: Try to delete the governance resource group from the portal. Observe the lock error message.

5. **Policy Authoring Exercise**: Write a custom policy that requires an "Environment" tag with values restricted to "dev", "staging", or "prod".

6. **Management Group Exercise**: In Portal → Management Groups, explore the hierarchy and understand how subscription placement affects policy inheritance.
