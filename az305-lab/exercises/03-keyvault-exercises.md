# Module 03: Key Vault & Secrets Management — Exercises

## Exercise 1: Retrieve a Secret from Key Vault Using CLI
**Difficulty:** 🟢 Guided
**Method:** CLI
**Estimated Time:** 10 minutes

### Objective
Retrieve a secret from Azure Key Vault using the Azure CLI to understand how applications interact with Key Vault.

### Instructions
1. List all Key Vaults in the lab resource group:
   ```bash
   az keyvault list \
     --resource-group rg-az305-lab \
     --output table
   ```
2. List all secrets stored in the Key Vault:
   ```bash
   az keyvault secret list \
     --vault-name <vault-name> \
     --output table --query "[].{Name:name, Enabled:attributes.enabled, ContentType:contentType}"
   ```
3. Retrieve the value of a specific secret:
   ```bash
   az keyvault secret show \
     --vault-name <vault-name> \
     --name <secret-name> \
     --output json | jq '{name: .name, value: .value, created: .attributes.created}'
   ```
4. View all versions of the secret:
   ```bash
   az keyvault secret list-versions \
     --vault-name <vault-name> \
     --name <secret-name> \
     --output table
   ```
5. Retrieve a specific (non-current) version:
   ```bash
   az keyvault secret show \
     --vault-name <vault-name> \
     --name <secret-name> \
     --version <version-id>
   ```

### Success Criteria
- You can list and retrieve secrets from the Key Vault.
- You understand that secrets have versions and that the latest version is returned by default.
- You can identify the secret's metadata (creation date, content type, enabled status).

### Explanation
AZ-305 tests whether you know that Key Vault is the recommended centralized secret store. The exam expects you to understand versioning (new secret values create new versions, old versions are retained) and that access is controlled via either RBAC (recommended) or access policies (legacy). Applications should never store secrets in code, config files, or environment variables.

---

## Exercise 2: Verify Key Vault RBAC Permissions
**Difficulty:** 🟢 Guided
**Method:** CLI
**Estimated Time:** 10 minutes

### Objective
Inspect the access control model on the Key Vault to understand who can access secrets, keys, and certificates.

### Instructions
1. Check whether the Key Vault uses RBAC or access policies:
   ```bash
   az keyvault show \
     --name <vault-name> \
     --output json | jq '{enableRbacAuthorization, enableSoftDelete, enablePurgeProtection}'
   ```
2. If RBAC is enabled, list the role assignments on the Key Vault:
   ```bash
   az role assignment list \
     --scope "/subscriptions/<sub-id>/resourceGroups/rg-az305-lab/providers/Microsoft.KeyVault/vaults/<vault-name>" \
     --output table
   ```
3. Identify which principals have `Key Vault Secrets Officer` vs. `Key Vault Secrets User`:
   ```bash
   az role assignment list \
     --scope "/subscriptions/<sub-id>/resourceGroups/rg-az305-lab/providers/Microsoft.KeyVault/vaults/<vault-name>" \
     --output json | jq '.[] | {principal: .principalName, role: .roleDefinitionName}'
   ```
4. If access policies are used instead, list them:
   ```bash
   az keyvault show \
     --name <vault-name> \
     --output json | jq '.properties.accessPolicies'
   ```

### Success Criteria
- You can identify whether the vault uses RBAC or access policies.
- You can list who has access and what level of access they have.
- You understand the difference between `Secrets Officer` (read/write) and `Secrets User` (read-only).

### Explanation
The exam strongly favors RBAC over access policies for Key Vault. RBAC provides finer granularity, integrates with Entra ID Privileged Identity Management (PIM), and uses the standard Azure authorization model. Access policies are legacy and don't support conditions or PIM. When the exam asks "how should you configure access to Key Vault," the answer is almost always Azure RBAC.

---

## Exercise 3: Create a New Secret and Grant Access to the Managed Identity
**Difficulty:** 🟡 Intermediate
**Method:** CLI
**Estimated Time:** 20 minutes

### Objective
Create a new secret in Key Vault and configure a managed identity to access it, simulating a real-world application deployment pattern.

### Instructions
1. Create a new secret in the Key Vault:
   ```bash
   az keyvault secret set \
     --vault-name <vault-name> \
     --name "db-connection-string" \
     --value "Server=myserver.database.windows.net;Database=mydb;Authentication=Active Directory Default"
   ```
2. Identify the managed identity of a compute resource (VM, App Service, etc.):
   ```bash
   az vm identity show \
     --resource-group rg-az305-lab \
     --name <vm-name> \
     --output json | jq '.principalId'
   ```
3. Grant the managed identity the `Key Vault Secrets User` role:
   ```bash
   az role assignment create \
     --assignee-object-id <principal-id> \
     --assignee-principal-type ServicePrincipal \
     --role "Key Vault Secrets User" \
     --scope "/subscriptions/<sub-id>/resourceGroups/rg-az305-lab/providers/Microsoft.KeyVault/vaults/<vault-name>"
   ```
4. Verify the role assignment:
   ```bash
   az role assignment list \
     --assignee <principal-id> \
     --scope "/subscriptions/<sub-id>/resourceGroups/rg-az305-lab/providers/Microsoft.KeyVault/vaults/<vault-name>" \
     --output table
   ```

### Success Criteria
- The secret exists in the Key Vault.
- The managed identity has the `Key Vault Secrets User` role on the vault.
- The managed identity can retrieve the secret (test from the VM if possible).

### Explanation
This is the exam's golden pattern for secret access: Managed Identity + Key Vault + RBAC. No credentials are stored anywhere — the managed identity is automatically provisioned by Azure, and RBAC controls who can read which secrets. The exam frequently presents alternatives (storing credentials in app settings, using SAS tokens) and expects you to choose managed identity + Key Vault.

---

## Exercise 4: Test Private Endpoint Connectivity
**Difficulty:** 🟡 Intermediate
**Method:** CLI
**Estimated Time:** 20 minutes

### Objective
Verify that Key Vault is accessible only through a private endpoint and not through the public internet.

### Instructions
1. Check the Key Vault's network configuration:
   ```bash
   az keyvault show \
     --name <vault-name> \
     --output json | jq '{publicNetworkAccess: .properties.publicNetworkAccess, networkAcls: .properties.networkAcls}'
   ```
2. List private endpoint connections on the Key Vault:
   ```bash
   az keyvault private-endpoint-connection list \
     --vault-name <vault-name> \
     --output table
   ```
3. From a VM inside the VNet, resolve the Key Vault DNS name:
   ```bash
   nslookup <vault-name>.vault.azure.net
   ```
   The response should resolve to a private IP address (10.x.x.x) if the private DNS zone is configured correctly.
4. From your local machine (outside the VNet), try the same lookup:
   ```bash
   nslookup <vault-name>.vault.azure.net
   ```
   Compare the results — it should resolve to a public IP (or `privatelink` CNAME).
5. Attempt to access the Key Vault from outside the VNet and observe the response:
   ```bash
   az keyvault secret list --vault-name <vault-name>
   ```

### Success Criteria
- DNS resolution from inside the VNet returns a private IP.
- DNS resolution from outside the VNet shows the `privatelink` CNAME chain.
- Access from outside the VNet is blocked (if public access is disabled).
- Access from inside the VNet succeeds.

### Explanation
Private endpoints are a critical AZ-305 topic. The exam tests whether you know that private endpoints use Azure Private DNS zones for name resolution, that the DNS CNAME chain redirects `vault.azure.net` → `privatelink.vaultcore.azure.net` → private IP. The exam also tests that private endpoints don't automatically disable public access — you must explicitly set `publicNetworkAccess` to `Disabled`.

---

## Exercise 5: Rotate a Key Vault Key and Update Dependent Resources
**Difficulty:** 🔴 Challenge
**Method:** CLI
**Estimated Time:** 30 minutes

### Objective
Perform a key rotation in Key Vault and update all resources that depend on the key, simulating an operational security practice.

### Instructions
1. List all keys in the Key Vault and identify one used for encryption (e.g., storage account CMK):
   ```bash
   az keyvault key list --vault-name <vault-name> --output table
   ```
2. Create a new version of the key:
   ```bash
   az keyvault key rotate --vault-name <vault-name> --name <key-name>
   ```
3. Verify the new version is created:
   ```bash
   az keyvault key list-versions --vault-name <vault-name> --name <key-name> --output table
   ```
4. If the key is used for storage account encryption (Customer-Managed Key):
   - Check which key version the storage account references.
   - Update the storage account to use the new key version (or configure auto-rotation).
5. Verify the storage account encryption is working with the new key version.

Consider:
- What happens to data encrypted with the old key version?
- How does automatic key rotation work?
- What is the role of the key's expiration date in rotation policies?

### Success Criteria
- A new key version is created in Key Vault.
- Dependent resources are updated to use the new key version.
- You can explain the difference between manual rotation and automatic rotation.
- You understand that old key versions must be retained to decrypt previously encrypted data.

### Explanation
Key rotation is tested in AZ-305 as part of security best practices. The exam expects you to know that Key Vault supports automatic key rotation policies, that Customer-Managed Keys (CMK) in storage accounts can be configured to auto-detect new key versions, and that you should never delete old key versions while data encrypted with them still exists. The rotation lifecycle is: create new version → update consumers → verify → (optionally) disable old version after a grace period.

---

## Exercise 6: Design a Zero-Credential Application Architecture
**Difficulty:** 🔴 Challenge
**Method:** Conceptual
**Estimated Time:** 30 minutes

### Objective
**Scenario:** An application needs to access a database password stored in Key Vault without any credentials in code. The application runs on Azure App Service and connects to Azure SQL Database. The security team requires: no secrets in code, no secrets in environment variables, audit trail of all secret access, and the ability to revoke access instantly.

Design the complete solution.

### Instructions
Address these design components:

1. **Identity:**
   - System-assigned vs. user-assigned managed identity — which and why?
   - What are the trade-offs of each for this scenario?

2. **Key Vault configuration:**
   - RBAC vs. access policies — which model?
   - What role should the managed identity have? (Least privilege)
   - Should the secret be referenced directly or via App Service Key Vault reference?

3. **App Service integration:**
   - How does the app access the secret? (SDK, Key Vault reference, or env variable?)
   - What is the `@Microsoft.KeyVault(SecretUri=...)` syntax and when to use it?

4. **Network security:**
   - Should the Key Vault have a private endpoint?
   - VNet integration for App Service — is it needed?

5. **Auditing:**
   - How do you enable audit logging for Key Vault access?
   - Where should logs be sent?

6. **Alternative approach — eliminate the password entirely:**
   - Can the app connect to Azure SQL using managed identity directly (no password at all)?
   - When would you still need a Key Vault secret vs. using direct managed identity auth?

### Success Criteria
- The design uses managed identity (no credentials in code).
- Key Vault access is controlled via RBAC with least privilege.
- Audit logging is enabled via diagnostic settings to Log Analytics.
- The design considers whether the password is even necessary (managed identity to SQL is preferred).
- Network security includes private endpoints and VNet integration.

### Explanation
This is a signature AZ-305 question. The best answer is actually to eliminate the secret entirely — Azure SQL supports Entra ID authentication, so the App Service managed identity can authenticate directly to SQL without any password. Key Vault is still used for secrets that can't be eliminated (third-party API keys, connection strings to non-Azure services). The exam rewards solutions that reduce the attack surface by removing secrets rather than just securing them.
