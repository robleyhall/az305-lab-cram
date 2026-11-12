# =============================================================================
# AZ-305 Lab — Module 02: Identity & Access
# =============================================================================
# 🟡 PARTIALLY DEPLOYABLE — Entra ID (Azure AD) free-tier objects deploy fine.
#    Conditional Access requires Entra ID P1+. PIM / Access Reviews require P2.
#
# This module demonstrates identity concepts tested on the AZ-305 exam:
#   - Entra ID security groups and role-based access control (RBAC)
#   - Application registrations and service principals
#   - Conditional Access policies (P1+)
#   - Diagnostic logging for Entra ID sign-in and audit events
#
# Concepts explained in comments but NOT deployable in this lab:
#   - Azure AD Connect / Entra Connect Cloud Sync (requires on-prem AD)
#   - Privileged Identity Management (PIM) — requires Entra ID P2
#   - Access Reviews — requires Entra ID P2
#   - B2B / B2C identity models
# =============================================================================

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 3.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "azurerm" {
  features {}
}

provider "azuread" {}

# -----------------------------------------------------------------------------
# Data Sources
# -----------------------------------------------------------------------------
# Retrieve the current client configuration so we can reference the tenant ID
# and object ID of whoever is running Terraform. This is essential for RBAC
# assignments and ensuring the deployer retains access.

data "azuread_client_config" "current" {}

data "azurerm_client_config" "current" {}

# -----------------------------------------------------------------------------
# Local values
# -----------------------------------------------------------------------------
locals {
  common_tags = merge(var.tags, {
    Module  = "02-identity"
    Purpose = "Identity and access management"
  })
}

# -----------------------------------------------------------------------------
# Random suffix — unique resource names across parallel deployments
# -----------------------------------------------------------------------------
resource "random_string" "suffix" {
  length  = 6
  upper   = false
  special = false
}

# =============================================================================
# RESOURCE GROUP
# =============================================================================
# Each lab module gets its own resource group. This makes it easy to tear down
# a single module without affecting others — a pattern you'll see in real
# enterprise Azure environments.

resource "azurerm_resource_group" "identity" {
  name     = "${var.prefix}-mod02-identity-rg-${random_string.suffix.result}"
  location = var.location
  tags     = local.common_tags

  lifecycle {
    # Non-semantic: Azure auto-adds rg-class tag for internal classification. Not a config choice.
    ignore_changes = [tags["rg-class"]]
  }
}

# =============================================================================
# ENTRA ID SECURITY GROUPS
# =============================================================================
# AZ-305 Exam Relevance:
#   - Security groups are the backbone of Azure RBAC
#   - Nest users into groups, then assign roles to groups (never to individuals)
#   - Dynamic groups (P1+) auto-add users based on attribute rules
#   - Group-based licensing assigns Entra ID/M365 licenses automatically
#
# Best Practice: Use a tiered group structure:
#   Tier 0 — Platform admins (break-glass accounts, global admins)
#   Tier 1 — Workload admins (subscription contributors, resource owners)
#   Tier 2 — Developers and operators (scoped to specific resource groups)
#   Tier 3 — Readers and auditors (read-only, no write access)
# -----------------------------------------------------------------------------

resource "azuread_group" "admins" {
  display_name     = "${var.prefix}-admins"
  description      = "Lab administrators — maps to Tier 0/1 in a real environment"
  security_enabled = true

  # mail_enabled must be false for pure security groups.
  # Mail-enabled security groups are an M365 concept.
  mail_enabled = false

  # prevent_duplicate_names stops Terraform from creating a second group
  # if one with the same name already exists in the tenant.
  prevent_duplicate_names = true

  # In production you would also set:
  #   owners               = [data.azuread_client_config.current.object_id]
  #   assignable_to_role   = true   # Required if the group will hold Entra directory roles
  #   dynamic_membership   = { ... } # P1+ feature for attribute-based auto-membership
}

resource "azuread_group" "developers" {
  display_name           = "${var.prefix}-developers"
  description            = "Lab developers — maps to Tier 2 in a real environment"
  security_enabled       = true
  mail_enabled           = false
  prevent_duplicate_names = true
}

resource "azuread_group" "readers" {
  display_name           = "${var.prefix}-readers"
  description            = "Lab readers — maps to Tier 3 (auditors / read-only) in a real environment"
  security_enabled       = true
  mail_enabled           = false
  prevent_duplicate_names = true
}

# =============================================================================
# AZ-305 CONCEPT: MANAGED IDENTITY vs SERVICE PRINCIPAL vs APP REGISTRATION
# =============================================================================
# This is one of the most frequently tested identity topics on AZ-305.
#
# ┌─────────────────────┬──────────────────────────────────────────────────────┐
# │ Identity Type        │ When to Use                                         │
# ├─────────────────────┼──────────────────────────────────────────────────────┤
# │ Managed Identity     │ Azure resource → Azure resource (no credentials)    │
# │   - System-assigned  │ Tied to one resource lifecycle. Deleted with it.    │
# │   - User-assigned    │ Shared across resources. Independent lifecycle.     │
# ├─────────────────────┼──────────────────────────────────────────────────────┤
# │ Service Principal    │ Non-Azure app or CI/CD pipeline needs Azure access  │
# │                      │ Backed by an App Registration. Has credentials.     │
# ├─────────────────────┼──────────────────────────────────────────────────────┤
# │ App Registration     │ Defines *what* the app is (permissions, redirect    │
# │                      │ URIs, etc.). The SP is the local instance of it.    │
# └─────────────────────┴──────────────────────────────────────────────────────┘
#
# Exam Tip: If the question says "no credentials to manage" → Managed Identity.
#           If the question says "external CI/CD" or "multi-tenant" → Service Principal.
#           Managed Identity is ALWAYS preferred when available.
# =============================================================================

# =============================================================================
# APPLICATION REGISTRATION + SERVICE PRINCIPAL
# =============================================================================
# An App Registration defines the application's identity metadata in Entra ID.
# A Service Principal is the local representation of that app in your tenant.
#
# Real-world analogy:
#   App Registration = the blueprint for the app (like a class definition)
#   Service Principal = an instance of that app in your tenant (like an object)
#
# In multi-tenant apps, one App Registration exists in the home tenant,
# but each consuming tenant gets its own Service Principal.
# -----------------------------------------------------------------------------

resource "azuread_application" "lab_app" {
  display_name = "${var.prefix}-lab-app"

  # sign_in_audience controls who can authenticate:
  #   "AzureADMyOrg"           — single-tenant (this org only)
  #   "AzureADMultipleOrgs"    — multi-tenant (any Entra ID tenant)
  #   "AzureADandPersonalMicrosoftAccount" — includes consumer accounts
  sign_in_audience = "AzureADMyOrg"

  # In production you would also configure:
  #   web { redirect_uris = [...] }           # OAuth redirect URIs
  #   api { oauth2_permission_scope { ... } } # Custom scopes
  #   required_resource_access { ... }        # Microsoft Graph permissions
  #   app_role { ... }                        # Custom app roles

  tags = ["lab", "az305", "certforge"]

  # The owners list determines who can manage this app registration.
  owners = [data.azuread_client_config.current.object_id]
}

resource "azuread_service_principal" "lab_app" {
  client_id = azuread_application.lab_app.client_id

  # app_role_assignment_required = true means users must be explicitly
  # assigned to the app before they can get a token. Good for enterprise apps.
  app_role_assignment_required = false

  owners = [data.azuread_client_config.current.object_id]

  tags = ["lab", "az305", "certforge"]
}

# =============================================================================
# AZURE RBAC — ROLE ASSIGNMENTS
# =============================================================================
# AZ-305 Exam Relevance:
#   - Role assignments are the glue between identities and permissions
#   - Structure: WHO (principal) + WHAT (role definition) + WHERE (scope)
#   - Scope hierarchy: Management Group → Subscription → Resource Group → Resource
#   - Roles are inherited downward — an RG Contributor can manage all resources in it
#   - Use the LEAST PRIVILEGE principle — don't assign Owner when Contributor suffices
#   - Built-in roles cover most scenarios; custom roles fill gaps
#
# Common Exam Trap: "Owner" vs "Contributor" — Owner can manage RBAC assignments,
# Contributor cannot. If the question says "delegate access" → Owner or
# User Access Administrator is needed.
#
# Deny assignments: Override allow rules. Only creatable via Azure Blueprints
# or Azure managed apps — you cannot create them directly via ARM/Terraform.
# -----------------------------------------------------------------------------

# Reader role → readers group → identity resource group scope
resource "azurerm_role_assignment" "readers" {
  scope                = azurerm_resource_group.identity.id
  role_definition_name = "Reader"
  principal_id         = azuread_group.readers.object_id

  # skip_service_principal_aad_check avoids a race condition where Entra ID
  # hasn't fully replicated the group before ARM tries to validate it.
  # Only needed for newly-created principals in automation.
}

# Contributor role → developers group → identity resource group scope
resource "azurerm_role_assignment" "developers" {
  scope                = azurerm_resource_group.identity.id
  role_definition_name = "Contributor"
  principal_id         = azuread_group.developers.object_id
}

# =============================================================================
# CONDITIONAL ACCESS POLICY (Requires Entra ID P1+)
# =============================================================================
# AZ-305 Exam Relevance:
#   Conditional Access is Microsoft's Zero Trust policy engine. It evaluates
#   every authentication request against a set of conditions and enforces
#   access controls (grant/block/session).
#
# Policy evaluation order (CRITICAL for the exam):
#   1. All policies are evaluated in parallel for the sign-in
#   2. All applicable policies must be satisfied (AND logic)
#   3. Block overrides Grant — if ANY policy blocks, access is denied
#   4. Within Grant controls, you can choose "require all" or "require one"
#
# Common Conditional Access signals:
#   - User / group membership       - Device platform (iOS, Windows, etc.)
#   - Location (named/trusted IPs)  - Client app (browser, mobile, desktop)
#   - Sign-in risk level (P2)       - Device compliance state
#   - User risk level (P2)          - Application being accessed
#
# Exam Tip: "Require MFA for admins" → Conditional Access policy, NOT per-user MFA.
#           Per-user MFA is legacy. Conditional Access is the recommended approach.
# -----------------------------------------------------------------------------

resource "azuread_conditional_access_policy" "require_mfa_admins" {
  # This resource requires Entra ID P1 or P2 licensing.
  # Set enable_conditional_access = true in terraform.tfvars if you have P1+.
  count = var.enable_conditional_access ? 1 : 0

  display_name = "${var.prefix}-require-mfa-admins"
  state        = "enabledForReportingButNotEnforced"

  # Using "report-only" mode is a best practice when deploying new policies.
  # It lets you see what WOULD happen without actually blocking anyone.
  # Transition to "enabled" only after reviewing the What If / Sign-in logs.

  conditions {
    client_app_types = ["all"]

    applications {
      included_applications = ["All"]
    }

    users {
      included_groups = [azuread_group.admins.object_id]

      # ALWAYS exclude break-glass accounts from Conditional Access.
      # A misconfigured policy can lock everyone out of the tenant.
      # excluded_users = ["<break-glass-account-object-id>"]
    }

    # You can also add location, device platform, and risk-level conditions:
    # locations {
    #   included_locations = ["All"]
    #   excluded_locations = ["AllTrusted"]  # Skip MFA from trusted office IPs
    # }
  }

  grant_controls {
    built_in_controls = ["mfa"]
    operator          = "OR"
  }

  # Session controls let you enforce:
  #   - Sign-in frequency (re-auth every N hours)
  #   - Persistent browser session (remember MFA)
  #   - Cloud App Security (inline CASB proxy)
  #   - Application enforced restrictions
  # session_controls { ... }
}

# =============================================================================
# AZ-305 CONCEPT: AZURE AD CONNECT / ENTRA CONNECT CLOUD SYNC
# =============================================================================
# These CANNOT be deployed in a lab (they require on-premises Active Directory),
# but they are HEAVILY tested on AZ-305.
#
# Two synchronization options:
#
# 1. Azure AD Connect (legacy, on-prem agent)
#    - Full-featured: password hash sync, pass-through auth, federation
#    - Single server installation (active-passive staging mode for HA)
#    - Supports filtering by OU, domain, or attribute
#    - Can do device writeback, group writeback, Exchange hybrid
#
# 2. Entra Connect Cloud Sync (modern, lightweight)
#    - Managed from the cloud — no heavy on-prem server needed
#    - Multi-forest support without complex networking
#    - Lightweight agent can run on any domain-joined server
#    - Fewer features than AD Connect but simpler to operate
#
# Password Hash Synchronization (PHS):
#   - Hashes of password hashes are synced to Entra ID (NOT plaintext!)
#   - Enables cloud authentication without on-prem dependency
#   - Required for Identity Protection risk detections (leaked credentials)
#   - Microsoft's recommended authentication method for most organizations
#   - Exam Tip: PHS is the simplest and most resilient auth method
#
# Pass-Through Authentication (PTA):
#   - Validates passwords directly against on-prem AD in real-time
#   - No password data stored in the cloud
#   - Requires on-prem agent(s) for HA
#   - Use when compliance requires passwords never leave on-prem
#
# Federation (AD FS):
#   - Most complex option — requires AD FS farm infrastructure
#   - Use when you need: smart card auth, 3rd-party MFA, or certificate auth
#   - Exam Tip: AD FS is almost never the correct answer unless the question
#     specifically mentions smart cards or third-party MFA requirements
#
# Seamless SSO:
#   - Works with PHS or PTA (not federation — it has its own SSO)
#   - Uses Kerberos tickets from domain-joined devices
#   - User gets automatic sign-in to cloud apps on corporate network
#   - Exam Tip: Seamless SSO is the answer when "users shouldn't see a
#     login prompt on corporate devices"
# =============================================================================

# =============================================================================
# AZ-305 CONCEPT: B2B vs B2C IDENTITY
# =============================================================================
# Both are Entra External Identities features. They solve different problems:
#
# B2B (Business-to-Business):
#   - Invite external users (partners, vendors) into YOUR tenant as guests
#   - Guest users show up in your directory with a #EXT# suffix
#   - They authenticate against THEIR home tenant or social IdP
#   - You control what they can access via RBAC in your tenant
#   - Cross-tenant access settings control B2B trust relationships
#   - Free for up to 50,000 MAU (monthly active users)
#
# B2C (Business-to-Consumer):
#   - Separate Entra ID tenant purpose-built for consumer/customer identity
#   - Supports local accounts (email/password) and social IdPs (Google, Facebook)
#   - Fully customizable sign-in/sign-up user flows
#   - Custom policies (Identity Experience Framework) for complex journeys
#   - Scales to millions of users
#   - Billed per authentication (~$0.00325/auth after 50K free)
#
# Exam Decision Tree:
#   "Partners need access to our SharePoint"   → B2B
#   "Customers need to sign in to our web app" → B2C
#   "Employees from acquired company"          → B2B (or tenant migration)
#   "Social login (Google, Facebook)"          → B2C
# =============================================================================

# =============================================================================
# AZ-305 CONCEPT: PRIVILEGED IDENTITY MANAGEMENT (PIM)
# =============================================================================
# Requires Entra ID P2. Cannot be deployed via Terraform.
# HEAVILY tested on AZ-305 — know these concepts cold:
#
# PIM provides Just-In-Time (JIT) privileged access:
#   - Roles are "eligible" not "active" — users must activate when needed
#   - Activation requires justification, approval, and optionally MFA
#   - Time-bound: activations expire after a configured duration (e.g., 8 hours)
#   - Audit trail: every activation is logged for compliance
#
# PIM for Azure Resources:
#   - Same JIT model for Azure RBAC roles (Contributor, Owner, etc.)
#   - Can require approval workflows before activation
#   - Alerts for suspicious activation patterns
#
# Exam Tip: If the question mentions "just-in-time", "time-limited",
#           "eligible roles", or "reduce standing access" → PIM is the answer.
#
# Access Reviews (also P2):
#   - Periodic review of who has access to what
#   - Reviewers: managers, resource owners, self-review, or specific users
#   - Auto-remediation: remove access if review is not completed
#   - Can review: group memberships, app assignments, Azure role assignments
#   - Exam Tip: "quarterly review of access" or "certify access" → Access Reviews
# =============================================================================

# =============================================================================
# DIAGNOSTIC SETTINGS — Entra ID Logs → Log Analytics
# =============================================================================
# Sends Entra ID sign-in logs and audit logs to the shared Log Analytics
# workspace from the foundation module. This enables:
#   - Querying sign-in patterns with KQL in Log Analytics
#   - Creating alerts on suspicious sign-in activity
#   - Long-term retention beyond Entra ID's default 30-day window
#   - Correlating identity events with Azure resource activity
#
# AZ-305 Exam Relevance:
#   - Know that Entra ID logs can go to: Log Analytics, Storage Account,
#     Event Hub, or a partner SIEM
#   - Sign-in logs require at least Entra ID P1 for full detail
#   - Audit logs are available on all tiers
#
# NOTE: This resource requires the deploying principal to have the
# "Security Administrator" or "Global Administrator" Entra ID role, plus
# "Log Analytics Contributor" on the target workspace.
# -----------------------------------------------------------------------------

resource "azurerm_monitor_aad_diagnostic_setting" "entra_logs" {
  count = var.enable_entra_diagnostics ? 1 : 0

  name                       = "${var.prefix}-entra-diag"
  log_analytics_workspace_id = var.log_analytics_workspace_id

  # Retention is configured on the Log Analytics workspace itself (30 days
  # in the foundation module), not on the diagnostic setting.

  enabled_log {
    category = "SignInLogs"
  }

  enabled_log {
    category = "AuditLogs"
  }

  # Additional log categories available (uncomment as needed):
  #
  # enabled_log {
  #   category = "NonInteractiveUserSignInLogs"  # Service account / daemon sign-ins
  # }
  # enabled_log {
  #   category = "ServicePrincipalSignInLogs"    # SP and managed identity sign-ins
  # }
  # enabled_log {
  #   category = "ManagedIdentitySignInLogs"     # Managed identity token acquisitions
  # }
  # enabled_log {
  #   category = "ProvisioningLogs"              # Entra ID provisioning events
  # }
  # enabled_log {
  #   category = "RiskyUsers"                    # Identity Protection (P2)
  # }
  # enabled_log {
  #   category = "UserRiskEvents"                # Identity Protection (P2)
  # }
}

# =============================================================================
# AZ-305 CONCEPT: USER-ASSIGNED MANAGED IDENTITY (demonstration)
# =============================================================================
# This creates a user-assigned managed identity to demonstrate the concept.
# Other lab modules (compute, app architecture) will reference this identity
# to show how workloads authenticate to Azure resources without credentials.
#
# System-assigned vs User-assigned:
#   System-assigned: created WITH the resource, deleted WITH the resource.
#                    1:1 relationship. Simplest option.
#   User-assigned:   created independently, can be shared across resources.
#                    1:many relationship. Better for shared identities.
#
# Exam Tip: "VM needs access to Key Vault" → Managed Identity (system-assigned
# unless it needs to be shared across VMs, then user-assigned).
# -----------------------------------------------------------------------------

resource "azurerm_user_assigned_identity" "lab_identity" {
  name                = "${var.prefix}-lab-uami-${random_string.suffix.result}"
  location            = azurerm_resource_group.identity.location
  resource_group_name = azurerm_resource_group.identity.name
  tags                = local.common_tags
}
