# =============================================================================
# AZ-305 Lab — Module 03: Key Vault & Application Identity
# =============================================================================
# This module demonstrates Azure Key Vault secrets management, managed
# identities, RBAC-based access control, and private endpoint connectivity.
#
# AZ-305 Exam Relevance:
#   - Design solutions for secrets, keys, and certificates (high weight)
#   - Choose between access policies and RBAC authorization
#   - Design managed identity strategy (system vs user-assigned)
#   - Design private connectivity for PaaS services
#   - Understand soft delete and purge protection implications
#   - Key rotation and certificate lifecycle management concepts
#
# Cost: ~$0.50/day (Key Vault standard SKU + private endpoint)
# =============================================================================

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "azurerm" {
  features {
    key_vault {
      # In a lab environment we want to fully remove vaults on destroy.
      # In production you would NEVER set this — purge protection exists
      # to guard against accidental or malicious deletion.
      purge_soft_delete_on_destroy = true
    }
  }
}

# -----------------------------------------------------------------------------
# Data Sources — current context for RBAC and network rules
# -----------------------------------------------------------------------------

# Retrieve the current Azure CLI / service principal identity.
# Used to grant the deploying user Key Vault Administrator rights so
# Terraform (and you) can manage secrets, keys, and certificates.
data "azurerm_client_config" "current" {}

# Fetch the current public IP so we can allow it through the Key Vault
# firewall. Without this, Terraform operations would be blocked by the
# network rules we configure below.
data "http" "my_ip" {
  url = "https://api.ipify.org"
}

# -----------------------------------------------------------------------------
# Local values
# -----------------------------------------------------------------------------
locals {
  common_tags = merge(var.tags, {
    Module  = "03-keyvault"
    Purpose = "Key Vault and managed identity"
  })
}

# -----------------------------------------------------------------------------
# Random suffix — globally unique Key Vault name
# -----------------------------------------------------------------------------
# Key Vault names must be globally unique (3-24 chars, alphanumeric + hyphens).
# The random suffix prevents collisions across lab deployments.
resource "random_string" "suffix" {
  length  = 6
  upper   = false
  special = false
}

# =============================================================================
# Resource Group
# =============================================================================
resource "azurerm_resource_group" "keyvault" {
  name     = "${var.prefix}-keyvault-rg-${random_string.suffix.result}"
  location = var.location
  tags     = local.common_tags

  lifecycle {
    ignore_changes = [tags["rg-class"]]
  }
}

# =============================================================================
# User-Assigned Managed Identity
# =============================================================================
# AZ-305 EXAM TOPIC: Managed Identity Types
# ---------------------------------------------------------------------------
# Azure provides two flavours of managed identity:
#
#   System-assigned:
#     - Tied 1:1 to a single Azure resource (e.g., a VM or App Service).
#     - Created and deleted with the parent resource.
#     - Best when one resource needs its own identity.
#
#   User-assigned:
#     - Created as a standalone resource; can be attached to MANY resources.
#     - Lifecycle is independent of any consuming resource.
#     - Best when multiple resources share the same set of permissions
#       (e.g., several VMs all need to read secrets from the same Key Vault).
#
# This lab uses a user-assigned identity so you can later attach it to VMs,
# App Services, or Functions in other modules without creating new identities.
# ---------------------------------------------------------------------------
resource "azurerm_user_assigned_identity" "main" {
  name                = "${var.prefix}-managed-id-${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.keyvault.name
  location            = azurerm_resource_group.keyvault.location
  tags                = local.common_tags
}

# =============================================================================
# Azure Key Vault
# =============================================================================
# AZ-305 EXAM TOPIC: Access Policies vs RBAC Authorization
# ---------------------------------------------------------------------------
# Key Vault supports two authorization models:
#
#   Access Policies (legacy):
#     - Configured directly on the vault resource.
#     - Flat list; no inheritance; hard to audit at scale.
#     - Maximum of 1024 policies per vault.
#
#   RBAC Authorization (modern, recommended):
#     - Uses Azure role assignments (same model as all other Azure resources).
#     - Supports Conditional Access, PIM, and audit via Activity Log.
#     - Granular built-in roles: Key Vault Administrator, Secrets User,
#       Crypto User, Certificates Officer, etc.
#     - Easier to manage at scale with Azure Policy and management groups.
#
# Microsoft recommends RBAC for all new deployments. This lab uses RBAC.
# ---------------------------------------------------------------------------
#
# AZ-305 EXAM TOPIC: Soft Delete & Purge Protection
# ---------------------------------------------------------------------------
# Soft delete (enabled by default since Feb 2025):
#   - Deleted vaults and objects are retained for a configurable period
#     (7–90 days). During this window they can be recovered.
#   - We use 7 days here to minimise lab costs; production should use 90.
#
# Purge protection:
#   - When ENABLED, even subscription owners cannot permanently delete a
#     vault or its objects during the retention period. This guards against
#     malicious or accidental data destruction.
#   - In this lab we DISABLE it so `terraform destroy` can clean up fully.
#   - In production: ALWAYS enable purge protection for compliance.
# ---------------------------------------------------------------------------
#
# AZ-305 EXAM TOPIC: Key Vault Firewall & Network Rules
# ---------------------------------------------------------------------------
# Key Vault supports network ACLs to restrict access:
#   - default_action = "Deny"  → blocks all traffic not explicitly allowed.
#   - virtual_network_subnet_ids → allows traffic from specific VNet subnets.
#   - ip_rules → allows specific public IPs (e.g., your workstation).
#   - bypass = "AzureServices" → lets trusted Azure services (Backup, Disk
#     Encryption, ARM template deployment) bypass the firewall.
#
# In production, combine network rules with a private endpoint (below) for
# defence in depth. The private endpoint provides a private IP inside your
# VNet so Key Vault traffic never traverses the public internet.
# ---------------------------------------------------------------------------

resource "azurerm_key_vault" "main" {
  name                = "${var.prefix}-kv-${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.keyvault.name
  location            = azurerm_resource_group.keyvault.location
  tenant_id           = data.azurerm_client_config.current.tenant_id
  tags                = local.common_tags

  sku_name = "standard"

  # RBAC authorization — see exam topic notes above.
  rbac_authorization_enabled = true

  # Soft delete — 7 days for lab; use 90 in production.
  soft_delete_retention_days = 7

  # Purge protection — disabled for easy lab teardown.
  purge_protection_enabled = false

  # Network ACLs — defence in depth alongside the private endpoint.
  network_acls {
    default_action             = "Deny"
    bypass                     = "AzureServices"
    virtual_network_subnet_ids = [var.keyvault_subnet_id]
    ip_rules                   = [data.http.my_ip.response_body]
  }
}

# =============================================================================
# Diagnostic Settings — send Key Vault logs to Log Analytics
# =============================================================================
# Centralised logging is critical for security auditing. Key Vault audit
# logs record every data-plane operation (secret reads, key usage, etc.)
# and management-plane changes (access policy updates, firewall changes).
resource "azurerm_monitor_diagnostic_setting" "keyvault" {
  name                       = "${var.prefix}-kv-diag"
  target_resource_id         = azurerm_key_vault.main.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "AuditEvent"
  }

  enabled_metric {
    category = "AllMetrics"
  }
}

# =============================================================================
# RBAC Role Assignments
# =============================================================================
# AZ-305 EXAM TOPIC: Least-Privilege Access
# ---------------------------------------------------------------------------
# Rather than granting broad "Contributor" access, use purpose-built Key
# Vault roles:
#
#   Key Vault Administrator      — full control (management + data plane)
#   Key Vault Secrets Officer     — manage secrets (CRUD)
#   Key Vault Secrets User        — read secrets only
#   Key Vault Crypto Officer      — manage keys (CRUD)
#   Key Vault Crypto User         — use keys for encrypt/decrypt/sign/verify
#   Key Vault Certificates Officer — manage certificates (CRUD)
#
# The deploying user gets Administrator (needed for Terraform to create
# secrets/keys/certs). The managed identity gets only the roles it needs.
# ---------------------------------------------------------------------------

# Grant the deploying user full Key Vault control.
resource "azurerm_role_assignment" "kv_admin_current_user" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = data.azurerm_client_config.current.object_id
}

# Grant the managed identity read access to secrets.
resource "azurerm_role_assignment" "kv_secrets_user_identity" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.main.principal_id
}

# Grant the managed identity permission to use cryptographic keys.
resource "azurerm_role_assignment" "kv_crypto_user_identity" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Crypto User"
  principal_id         = azurerm_user_assigned_identity.main.principal_id
}

# =============================================================================
# Key Vault Secret
# =============================================================================
# AZ-305 EXAM TOPIC: When to Use Secrets vs Keys vs Certificates
# ---------------------------------------------------------------------------
# Secrets: arbitrary values — connection strings, API keys, passwords.
#   → Use when your application needs to retrieve and use a plaintext value.
#
# Keys: cryptographic keys managed by Key Vault (RSA, EC).
#   → Use for encrypt/decrypt, sign/verify, wrap/unwrap operations.
#   → The private key NEVER leaves Key Vault — operations are performed
#     inside the HSM/software boundary.
#
# Certificates: X.509 certificates with automated lifecycle management.
#   → Use for TLS/SSL, code signing, or mutual authentication.
#   → Key Vault can auto-renew with integrated CAs (DigiCert, GlobalSign)
#     or generate self-signed certs for testing.
# ---------------------------------------------------------------------------

resource "azurerm_key_vault_secret" "db_connection_string" {
  name         = "db-connection-string"
  value        = "Server=tcp:az305-lab-sql.database.windows.net,1433;Database=az305-lab-db;Authentication=Active Directory Managed Identity;"
  key_vault_id = azurerm_key_vault.main.id
  content_type = "text/plain"
  tags         = local.common_tags

  # Ensure RBAC assignment propagates before creating the secret.
  depends_on = [azurerm_role_assignment.kv_admin_current_user]
}

# =============================================================================
# Key Vault Key
# =============================================================================
# AZ-305 EXAM TOPIC: Key Rotation
# ---------------------------------------------------------------------------
# Key rotation is a security best practice and compliance requirement.
# Strategies:
#   1. Manual rotation — create a new key version, update consuming apps.
#   2. Automated rotation — Key Vault can auto-rotate keys on a schedule
#      (preview). Apps using the key URI without a version automatically
#      pick up the latest version.
#   3. Bring Your Own Key (BYOK) — import HSM-protected keys generated
#      on-premises. Required for some compliance regimes (FIPS 140-2 L2+).
#
# For Customer Managed Keys (CMK) scenarios (encrypting Storage, SQL, Disks),
# the service creates a wrapped copy of your key. Rotation requires the
# service to re-wrap with the new key version.
# ---------------------------------------------------------------------------

resource "azurerm_key_vault_key" "encryption" {
  name         = "az305-lab-encryption-key"
  key_vault_id = azurerm_key_vault.main.id
  key_type     = "RSA"
  key_size     = 2048
  tags         = local.common_tags

  key_opts = [
    "decrypt",
    "encrypt",
    "sign",
    "verify",
    "wrapKey",
    "unwrapKey",
  ]

  depends_on = [azurerm_role_assignment.kv_admin_current_user]
}

# =============================================================================
# Key Vault Certificate (Self-Signed)
# =============================================================================
# Self-signed certs are useful for lab/dev TLS endpoints. In production,
# integrate with DigiCert or GlobalSign for trusted CA-issued certificates
# that Key Vault can auto-renew before expiry.

resource "azurerm_key_vault_certificate" "tls_demo" {
  name         = "az305-lab-tls-demo"
  key_vault_id = azurerm_key_vault.main.id
  tags         = local.common_tags

  certificate_policy {
    issuer_parameters {
      name = "Self"
    }

    key_properties {
      exportable = true
      key_size   = 2048
      key_type   = "RSA"
      reuse_key  = false
    }

    lifetime_action {
      action {
        action_type = "AutoRenew"
      }
      trigger {
        days_before_expiry = 30
      }
    }

    secret_properties {
      content_type = "application/x-pkcs12"
    }

    x509_certificate_properties {
      subject            = "CN=az305-lab-demo.azure.local"
      validity_in_months = 12

      key_usage = [
        "digitalSignature",
        "keyEncipherment",
      ]

      subject_alternative_names {
        dns_names = [
          "az305-lab-demo.azure.local",
          "*.az305-lab-demo.azure.local",
        ]
      }
    }
  }

  depends_on = [azurerm_role_assignment.kv_admin_current_user]
}

# =============================================================================
# Private Endpoint for Key Vault
# =============================================================================
# AZ-305 EXAM TOPIC: Private Endpoint Pattern (Frequently Tested)
# ---------------------------------------------------------------------------
# A private endpoint projects an Azure PaaS service into your VNet by
# creating a NIC with a private IP in your subnet. Traffic flows over the
# Microsoft backbone — never the public internet.
#
# Components of the pattern:
#   1. Private Endpoint resource — creates the NIC in your subnet.
#   2. Private DNS Zone — resolves the service's public FQDN to the
#      private IP (e.g., az305-lab-kv.vault.azure.net → 10.0.3.x).
#   3. DNS Zone VNet Link — connects the private DNS zone to your VNet
#      so VMs inside the VNet use the private resolution.
#
# Without the DNS zone, clients resolve the public IP and traffic goes
# over the internet (or gets blocked by the firewall rules above).
#
# Exam gotcha: Private endpoints work with Azure Private Link. The PaaS
# service must support Private Link. Key Vault, Storage, SQL, Cosmos DB,
# and most PaaS services do.
# ---------------------------------------------------------------------------

# Private DNS Zone for Key Vault
resource "azurerm_private_dns_zone" "keyvault" {
  name                = "privatelink.vaultcore.azure.net"
  resource_group_name = azurerm_resource_group.keyvault.name
  tags                = local.common_tags
}

# Link the private DNS zone to the VNet so name resolution works for all
# resources inside the network.
resource "azurerm_private_dns_zone_virtual_network_link" "keyvault" {
  name                  = "${var.prefix}-kv-dns-link"
  resource_group_name   = azurerm_resource_group.keyvault.name
  private_dns_zone_name = azurerm_private_dns_zone.keyvault.name
  virtual_network_id    = var.vnet_id
  registration_enabled  = false
  tags                  = local.common_tags
}

# The private endpoint itself — creates a NIC in the Key Vault subnet.
resource "azurerm_private_endpoint" "keyvault" {
  name                = "${var.prefix}-kv-pe-${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.keyvault.name
  location            = azurerm_resource_group.keyvault.location
  subnet_id           = var.keyvault_subnet_id
  tags                = local.common_tags

  private_service_connection {
    name                           = "${var.prefix}-kv-psc"
    private_connection_resource_id = azurerm_key_vault.main.id
    subresource_names              = ["vault"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "keyvault-dns-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.keyvault.id]
  }
}
