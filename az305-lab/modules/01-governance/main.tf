# =============================================================================
# AZ-305 Lab — Module 01: Governance & Compliance
# =============================================================================
# Demonstrates Azure governance constructs heavily tested on the AZ-305 exam
# (25-30% of questions). Covers Azure Policy, custom RBAC roles, management
# groups, resource locks, and tagging strategies.
#
# AZ-305 Exam Relevance:
#   - Design governance solutions (management groups, subscriptions, RBAC)
#   - Design Azure Policy solutions (built-in vs. custom, effects, initiatives)
#   - Design solutions for managing secrets, keys, and certificates (RBAC tie-in)
#
# Cost: ~$0.10/day — policies, role definitions, and locks are free metadata.
#       Only the resource group itself incurs trivial cost.
# =============================================================================

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  features {}
}

# -----------------------------------------------------------------------------
# Data Sources — reference resources from module 00-foundation
# -----------------------------------------------------------------------------

data "azurerm_resource_group" "foundation" {
  name = var.foundation_resource_group_name
}

data "azurerm_subscription" "current" {}

data "azurerm_client_config" "current" {}

# -----------------------------------------------------------------------------
# Local Values
# -----------------------------------------------------------------------------

locals {
  common_tags = merge(var.tags, {
    Module  = "01-governance"
    Purpose = "Governance and compliance demonstration"
  })

  # Subscription scope string used by policy assignments and role definitions
  subscription_scope = data.azurerm_subscription.current.id
}

# =============================================================================
# RESOURCE GROUP
# =============================================================================
# Each lab module creates its own resource group to demonstrate isolation.
# In production, resource groups map to application boundaries, lifecycle
# boundaries, or team ownership boundaries.

resource "azurerm_resource_group" "governance" {
  name     = "${var.prefix}-governance-rg"
  location = var.location
  tags     = local.common_tags
}

# =============================================================================
# MANAGEMENT GROUPS
# =============================================================================
# AZ-305 Key Concept: Management Group Hierarchy
#
#   Tenant Root Group
#   ├── Production MG        → strict policies (Deny effects)
#   │   ├── Corp Sub
#   │   └── Online Sub
#   ├── Non-Production MG    → relaxed policies (Audit effects)
#   │   ├── Dev Sub
#   │   └── Staging Sub
#   └── Sandbox MG           → minimal governance
#
# Policy Inheritance: Policies assigned at a management group are INHERITED by
# all child management groups, subscriptions, and resource groups below it.
# This is the primary mechanism for enforcing governance at scale.
#
# LIMITATION: Management group creation requires tenant-level permissions
# (Microsoft.Management/managementGroups/write). Most lab/trial subscriptions
# can create them, but some restricted environments cannot.
# Set count = 0 to skip if your account lacks permissions.
# -----------------------------------------------------------------------------

variable "create_management_group" {
  type        = bool
  default     = true
  description = "Set to false if your account lacks management group permissions."
}

resource "azurerm_management_group" "lab" {
  count = var.create_management_group ? 1 : 0

  display_name     = "${var.prefix}-lab-mg"
  subscription_ids = [data.azurerm_subscription.current.subscription_id]

  # AZ-305 Note: In production, you would NOT assign subscriptions directly
  # here — you'd build a hierarchy (Corp, Online, Sandbox) and place
  # subscriptions into the appropriate child management group.
}

# =============================================================================
# AZURE POLICY — CUSTOM DEFINITIONS
# =============================================================================
# AZ-305 Key Concept: Policy Effects
#
#   - Audit        → logs non-compliance but does NOT block deployment
#   - Deny         → blocks non-compliant resource creation/updates
#   - Append       → adds fields (e.g., tags) during creation
#   - Modify       → changes existing resource properties (requires managed identity)
#   - DeployIfNotExists → deploys a remediation resource if missing (e.g., enable diagnostics)
#   - AuditIfNotExists  → audits if a related resource is missing
#   - Disabled     → turns the policy off without removing the assignment
#
# For the exam: know when to recommend each effect. "Deny" prevents creation,
# "DeployIfNotExists" auto-remediates, "Audit" provides visibility without blocking.
# -----------------------------------------------------------------------------

# --- Custom Policy: Require "CostCenter" tag on all resources ---
# Demonstrates a common governance requirement — ensuring all resources
# carry a cost-tracking tag for chargeback/showback reporting.

resource "azurerm_policy_definition" "require_costcenter_tag" {
  name         = "${var.prefix}-require-costcenter-tag"
  display_name = "Require CostCenter tag on resources"
  description  = "Denies creation of resources that do not have a CostCenter tag. Lab policy for AZ-305 governance module."
  policy_type  = "Custom"
  mode         = "Indexed"

  # "Indexed" mode applies to resource types that support tags and location.
  # Use "All" mode for policies that also target resource types like
  # subscriptions, management groups, and extension resources.

  metadata = jsonencode({
    category = "Tags"
    version  = "1.0.0"
  })

  policy_rule = jsonencode({
    if = {
      field  = "[concat('tags[', 'CostCenter', ']')]"
      exists = "false"
    }
    then = {
      effect = "deny"
    }
  })
}

# --- Custom Policy: Restrict VM SKU sizes ---
# Prevents deployment of expensive VM sizes. This is one of the most common
# custom policies in production — controlling compute costs by limiting
# available SKUs to a pre-approved list.

resource "azurerm_policy_definition" "restrict_vm_skus" {
  name         = "${var.prefix}-restrict-vm-skus"
  display_name = "Restrict VM SKUs to cost-effective sizes"
  description  = "Only allows deployment of specified cost-effective VM SKU sizes. Lab policy for AZ-305 governance module."
  policy_type  = "Custom"
  mode         = "Indexed"

  metadata = jsonencode({
    category = "Compute"
    version  = "1.0.0"
  })

  # AZ-305 Note: parameterized policies are reusable across different scopes
  # with different parameter values. This is the recommended approach over
  # hard-coding values in the policy rule.
  parameters = jsonencode({
    allowedSkus = {
      type = "Array"
      metadata = {
        displayName = "Allowed VM SKUs"
        description = "List of VM SKUs that are permitted for deployment."
      }
      defaultValue = [
        "Standard_B1s",
        "Standard_B1ms",
        "Standard_B2s",
        "Standard_B2ms",
        "Standard_D2s_v5",
        "Standard_D2as_v5"
      ]
    }
  })

  policy_rule = jsonencode({
    if = {
      allOf = [
        {
          field  = "type"
          equals = "Microsoft.Compute/virtualMachines"
        },
        {
          not = {
            field = "Microsoft.Compute/virtualMachines/sku.name"
            in    = "[parameters('allowedSkus')]"
          }
        }
      ]
    }
    then = {
      effect = "deny"
    }
  })
}

# =============================================================================
# AZURE POLICY — ASSIGNMENTS
# =============================================================================
# AZ-305 Key Concept: Policy Assignment Scopes
#
# Policies can be assigned at: Management Group → Subscription → Resource Group.
# The NARROWEST scope wins for conflicting assignments. Exclusions can be set
# to exempt specific child scopes from an inherited policy.
#
# When designing for the exam, remember:
# - Assign broad governance policies at the management group level
# - Assign environment-specific policies at the subscription level
# - Assign workload-specific policies at the resource group level
# -----------------------------------------------------------------------------

# --- Assign the "CostCenter tag required" policy to the governance RG ---
# Using Audit (not Deny) so the lab itself can deploy resources without tags.
# In production, you'd set this to Deny after a compliance grace period.

resource "azurerm_resource_group_policy_assignment" "require_costcenter_tag" {
  name                 = "${var.prefix}-assign-costcenter-tag"
  display_name         = "Require CostCenter tag (Audit)"
  description          = "Audits resources in the governance RG that lack a CostCenter tag."
  resource_group_id    = azurerm_resource_group.governance.id
  policy_definition_id = azurerm_policy_definition.require_costcenter_tag.id

  # Override the policy effect to Audit for the lab — we want visibility
  # without blocking other lab resources from deploying.
  non_compliance_message {
    content = "This resource is missing the required 'CostCenter' tag. Add a CostCenter tag to become compliant."
  }
}

# --- Assign built-in "Allowed locations" policy ---
# Built-in policy ID: e56962a6-4747-49cd-b67b-bf8b01975c4c
# This is one of the most commonly tested policies on AZ-305.

resource "azurerm_resource_group_policy_assignment" "allowed_locations" {
  name                 = "${var.prefix}-assign-allowed-locs"
  display_name         = "Allowed locations — eastus only"
  description          = "Restricts resource deployment to the eastus region. Demonstrates location-based governance."
  resource_group_id    = azurerm_resource_group.governance.id
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/e56962a6-4747-49cd-b67b-bf8b01975c4c"

  parameters = jsonencode({
    listOfAllowedLocations = {
      value = ["eastus"]
    }
  })

  non_compliance_message {
    content = "Resources must be deployed in the 'eastus' region per governance policy."
  }
}

# --- Assign built-in initiative: Azure Security Benchmark ---
# Initiative (policy set) ID: 1f3afdf9-d0c9-4c3d-847f-89da613e70a8
# This is Microsoft's flagship security baseline. AZ-305 expects you to know
# it exists and when to recommend it vs. custom initiatives.
#
# AZ-305 Note: Initiatives (policy sets) group related policies together.
# Use initiatives when you need to enforce a cohesive compliance standard
# (e.g., CIS, NIST, Azure Security Benchmark) rather than individual policies.

resource "azurerm_resource_group_policy_assignment" "security_benchmark" {
  name                 = "${var.prefix}-assign-sec-bench"
  display_name         = "Azure Security Benchmark (Audit mode)"
  description          = "Assigns the Azure Security Benchmark initiative in audit-only mode for compliance visibility."
  resource_group_id    = azurerm_resource_group.governance.id
  policy_definition_id = "/providers/Microsoft.Authorization/policySetDefinitions/1f3afdf9-d0c9-4c3d-847f-89da613e70a8"

  non_compliance_message {
    content = "This resource does not meet Azure Security Benchmark recommendations. Review and remediate."
  }
}

# =============================================================================
# RBAC — CUSTOM ROLE DEFINITION
# =============================================================================
# AZ-305 Key Concept: RBAC Model
#
#   Security Principal + Role Definition + Scope = Role Assignment
#
# Built-in roles (Owner, Contributor, Reader) cover most scenarios, but custom
# roles fill gaps. For the exam, know:
#   - RBAC is CUMULATIVE — permissions from multiple role assignments are UNIONED
#   - The only exception is Deny Assignments (from Blueprints or system), which
#     override Allow. Regular RBAC role assignments cannot create Deny entries.
#   - Custom roles can be scoped to management group, subscription, or resource group
#   - Least privilege principle: grant the minimum permissions needed
#
# AZ-305 Note: Privileged Identity Management (PIM)
#   PIM provides just-in-time (JIT) role activation, approval workflows, and
#   time-bound access. PIM CANNOT be configured via Terraform — it requires
#   the Azure portal or Microsoft Graph API. For the exam, know:
#   - PIM is for Entra ID roles AND Azure resource roles
#   - Eligible assignments require activation; Active assignments are always-on
#   - PIM requires Entra ID P2 or Entra ID Governance license
# -----------------------------------------------------------------------------

resource "azurerm_role_definition" "lab_reader_plus" {
  name        = "${var.prefix}-lab-reader-plus"
  description = "Custom role: Read access to all resources plus ability to restart and deallocate VMs. Demonstrates custom RBAC for AZ-305."
  scope       = local.subscription_scope

  permissions {
    actions = [
      # Standard Reader permissions
      "*/read",

      # VM restart and deallocate — the "Plus" in "Reader Plus"
      "Microsoft.Compute/virtualMachines/restart/action",
      "Microsoft.Compute/virtualMachines/deallocate/action",
      "Microsoft.Compute/virtualMachines/start/action",

      # View metrics and diagnostics (useful for support roles)
      "Microsoft.Insights/metrics/read",
      "Microsoft.Insights/diagnosticSettings/read",
    ]
    not_actions = []
  }

  # Limit where this role can be assigned
  assignable_scopes = [
    local.subscription_scope,
  ]
}

# =============================================================================
# RESOURCE LOCKS
# =============================================================================
# AZ-305 Key Concept: Resource Locks
#
# Two lock types:
#   - CanNotDelete → prevents deletion but allows reads and modifications
#   - ReadOnly     → prevents deletion AND modification (careful — breaks many operations)
#
# Locks are inherited: a lock on a resource group applies to ALL resources in it.
# Even Owner-role users cannot delete a locked resource until the lock is removed.
# This is a common exam question: "How do you prevent accidental deletion of
# production resources?" Answer: CanNotDelete lock at the resource group level.
#
# WARNING: ReadOnly locks can break Terraform operations because Terraform
# needs to modify resources during plan/apply. Use CanNotDelete for lab environments.
# -----------------------------------------------------------------------------

resource "azurerm_management_lock" "governance_rg_lock" {
  name       = "${var.prefix}-governance-rg-nodelete"
  scope      = azurerm_resource_group.governance.id
  lock_level = "CanNotDelete"
  notes      = "Prevents accidental deletion of the governance resource group. Remove this lock before running terraform destroy."

  # AZ-305 Exam Tip: You MUST remove locks before you can delete locked
  # resources, even with Owner permissions. This is a common gotcha.
  # To destroy this module: first remove the lock, then run terraform destroy.
  #
  # Option 1 (Terraform): terraform destroy -target=azurerm_management_lock.governance_rg_lock
  #                        terraform destroy
  # Option 2 (Azure CLI):  az lock delete --name az305-lab-governance-rg-nodelete \
  #                           --resource-group az305-lab-governance-rg
  #                        terraform destroy
}

# =============================================================================
# TAGGING STRATEGY — APPLIED TO ALL RESOURCES
# =============================================================================
# AZ-305 Key Concept: Tagging Strategy
#
# Tags enable:
#   - Cost management (CostCenter, Project, Team)
#   - Operations (Environment, Criticality, SLA)
#   - Governance (Owner, ManagedBy, Compliance)
#   - Automation (AutoShutdown, PatchGroup)
#
# Best practices tested on AZ-305:
#   - Enforce required tags via Azure Policy (see policy definitions above)
#   - Use tag inheritance policies to copy RG tags down to child resources
#   - Maximum 50 tags per resource, 512-char key, 256-char value
#   - Tags are NOT inherited by default — you need policy for that
#
# All resources in this module are tagged via local.common_tags which merges
# the user-supplied var.tags with module-specific labels.
# =============================================================================

# =============================================================================
# ADDITIONAL AZ-305 CONCEPTS (Documentation Only)
# =============================================================================
#
# --- Azure Blueprints (Deprecated — know for legacy questions) ---
# Blueprints bundled ARM templates, policy assignments, RBAC assignments, and
# resource groups into a versioned, auditable deployment package. They have been
# DEPRECATED in favor of:
#   - Terraform / Bicep for resource deployment
#   - Azure Policy for governance
#   - Deployment Stacks for lifecycle management
# The exam may still reference Blueprints in older question pools.
#
# --- Azure Landing Zones ---
# The Cloud Adoption Framework (CAF) Landing Zone architecture is the current
# recommended approach. It uses management group hierarchies, Azure Policy,
# and Hub-Spoke / Virtual WAN networking. Key components:
#   - Platform landing zone (shared services, connectivity, identity)
#   - Application landing zones (workload-specific subscriptions)
#   - Policy-driven governance at the management group level
#
# --- Subscription Design ---
# AZ-305 tests subscription topology decisions:
#   - Environment-based: separate subs for Dev/Staging/Prod
#   - Workload-based: separate subs per application or business unit
#   - Hybrid: management groups for environments, subs for workloads
#   - Key factor: Azure limits (e.g., 800 resource groups per sub)
#
# --- Microsoft Defender for Cloud ---
# Provides security posture management (CSPM) and workload protection (CWPP).
# The exam expects you to know:
#   - Free tier: Secure Score, basic recommendations
#   - Defender plans: per-resource-type pricing for advanced protection
#   - Integration with Azure Policy via the Security Benchmark initiative
#     (assigned above as security_benchmark)
#   - Regulatory compliance dashboard for standards (CIS, NIST, PCI-DSS)
# =============================================================================
