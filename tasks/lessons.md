# Lessons Learned — AZ-305 CertForge Lab

> **Purpose:** Patterns, rules, and discoveries to prevent repeated mistakes and preserve institutional knowledge. Review at session start.

---

## Session: 2026-03-30

### Lesson 1: AZ-305 exercises should emphasize Portal and design scenarios, not CLI

**What happened:** Exercises were generated with heavy CLI focus. User correctly noted AZ-305 is a *design* exam — questions are scenario-based ("which service would you recommend?"), not implementation-based ("type the CLI command").

**Fix:** Rebalance exercises to prioritize: (1) Portal exploration and configuration understanding, (2) Design scenario questions matching exam format, (3) Architecture comparison/trade-off exercises. CLI is acceptable for verification but should not be the primary exercise method.

**Rule:** For AZ-305 (and other architect/design exams), exercises must match exam format: scenario-based design decisions, Portal walkthroughs, comparison tables, and "which approach" questions. CLI is fine in Explore & Verify sections (MS Learn uses CLI there too), but exercise *methodology* should be design-scenario-focused, not "run this az command." AZ-104-style exams can lean more CLI-heavy in exercises.

### Lesson 2: Subagents fail on very large single-file generation — write directly instead

**What happened:** Two subagents (`generate-labguide-1` and `generate-labguide-2`) were launched to create LAB-GUIDE.md in two halves. Both ran for 60+ minutes and never produced the file. The agents appeared to stall at 5-6 tool calls — likely the content was too large for a single `create` call, or the agents spent all their time composing the content before timing out.

**Fix:** Wrote the LAB-GUIDE.md directly in the main context using the `create` tool. The file was 52KB / ~780 lines and created successfully in one shot from the main session.

**Rule:** For very large single-file outputs (>30KB), write them directly in the main context rather than delegating to subagents. Subagents work well for multiple smaller files (e.g., Terraform modules with 5 files each) but struggle with single massive files. If a large file must be delegated, split it into genuinely separate files rather than two halves of one file.

### Lesson 3: Establish naming convention before generating any resources

**What happened:** All 13 Terraform modules and 52+ files were generated with the default `certlab` prefix. This required a global find-and-replace of `certlab` → `az305-lab` across all `.tf`, `.sh`, and `.md` files, plus edge-case fixes for Azure resources that don't allow hyphens (storage accounts, ACR, Batch accounts, action group short_name).

**Fix:** Global `sed` replacement across 52 files, then added `prefix_clean = replace(var.prefix, "-", "")` locals in modules 06-storage, 08-data-integration, 09-compute, and 12-migration for storage account names. Fixed action group `short_name` (12-char limit) and DNS zone name manually.

**Rule:** Establish the naming convention (prefix) before generating any IaC or documentation. If the prefix contains hyphens, ensure a `prefix_clean` local is available in any module that creates storage accounts, container registries, batch accounts, or other resources with alphanumeric-only naming constraints. Update the CertForge prompt's default naming convention if changing from `certlab`.

### Lesson 4: Always exclude .terraform/ from git before first commit

**What happened:** Terraform provider binaries (`.terraform/` directories, 233MB largest) were committed to git history. GitHub rejected the push due to the 100MB file size limit. Required squashing all history into a single commit + `git gc --prune=now` to remove the large objects.

**Fix:** Added `.terraform/` to `.gitignore`, removed from git index with `git rm --cached`, squashed all 14 commits into one clean commit, pruned reflog and GC'd. Repo went from 107MB → 492KB.

**Rule:** Before the first `git add`, ensure `.gitignore` includes `.terraform/`, `*.tfstate`, `*.tfstate.backup`, and `*.tfplan`. If subagents run `terraform init` inside module directories, those provider caches will be created — they must never be committed. Verify with `git ls-files | grep .terraform` before pushing.

### Lesson 5: Subagents can get stuck in terraform validation loops

**What happened:** The `generate-mod02` (identity module) agent ran for 75+ minutes, accumulating 36 tool calls while stuck in "Validating Terraform syntax." The files had actually been created and validated clean long before the agent completed. The agent appeared to be iterating unnecessarily.

**Fix:** Checked the files directly with `terraform validate` from the main session — they passed clean. Marked the module as done without waiting for the agent.

**Rule:** If a subagent has been running >20 minutes and its files already exist on disk, validate the files yourself from the main session. Don't wait indefinitely for a potentially stuck agent. Check file existence + `terraform validate` as a shortcut.

### Lesson 6: MCAPS/internal subscriptions restrict VM SKU families

**What happened:** `Standard_B1s` (and all B-series, D-series general purpose) VM SKUs returned `SkuNotAvailable` in eastus during module 05-ha-dr deployment. `az vm list-skus` confirmed zero B-series or standard D-series SKUs available — only DC-series (confidential computing), EC-series, FX-series, and L-series were listed.

**Fix:** Added a `vm_size` variable (default `Standard_B1s`) to modules 05, 09, and 12. Overrode in terraform.tfvars with `Standard_DC2s_v3` which was available. This is a subscription-type restriction (MCAPS-Hybrid), not a regional capacity issue — B-series isn't even listed as a SKU.

**Rule:** Before deploying VM resources, run `az vm list-skus --location <region> --resource-type virtualMachines` and check which families are available. MCAPS, Visual Studio, and other internal Microsoft subscriptions often restrict VM families entirely (not just capacity). Always parameterize `vm_size` as a variable with a sensible default, never hardcode SKU names in resources. If B-series is unavailable, DC2s_v3 is a fallback.

**Customer talking point:** Internal/partner subscriptions (MCAPS, MPN, VS Enterprise) have different VM family availability than Pay-As-You-Go or EA subscriptions. Always verify SKU availability with `az vm list-skus` before deployment.

### Lesson 7: Subnets need service endpoints before resources can use VNet rules

**What happened:** Module 03-keyvault failed with `SubnetsHaveNoServiceEndpointsConfigured` — the Key Vault had `network_acls` referencing the keyvault subnet, but the subnet didn't have `Microsoft.KeyVault` service endpoint enabled.

**Fix:** Added `service_endpoints` to the foundation module's subnet definitions: `Microsoft.KeyVault` on keyvault subnet, `Microsoft.Storage` on storage subnet, `Microsoft.Sql` on database subnet. Applied foundation update before retrying keyvault.

**Rule:** When a module creates a resource with VNet/subnet-based network rules (Key Vault, Storage, SQL), the referenced subnet must have the corresponding service endpoint pre-configured in the foundation module. Map: Key Vault → `Microsoft.KeyVault`, Storage → `Microsoft.Storage`, SQL → `Microsoft.Sql`, Cosmos DB → `Microsoft.AzureCosmosDB`. Add these to the foundation module's subnet definitions proactively.

### Lesson 8: Traffic Manager endpoints require DNS labels on public IPs

**What happened:** Module 05-ha-dr Traffic Manager endpoint creation failed with `BadRequest: does not have a DNS name` because the public IP for the load balancer lacked a `domain_name_label`.

**Fix:** Added `domain_name_label` to `azurerm_public_ip.lb` in module 05.

**Rule:** Any public IP that will be used as a Traffic Manager Azure endpoint must have `domain_name_label` set. Traffic Manager resolves endpoints via DNS — a bare IP without a DNS name is rejected.

### Lesson 9: Entra ID diagnostic settings require Global/Security Admin role

**What happened:** Module 02-identity failed creating `azurerm_monitor_aad_diagnostic_setting` with 403 Forbidden — the deploying user didn't have `Microsoft.AADIAM/diagnosticSettings/read` permission, which requires Security Administrator or Global Administrator Entra ID role.

**Fix:** Added `enable_entra_diagnostics` variable (default `false`) with `count` guard on the resource. Subscription Owner role is not sufficient — this is a tenant-level Entra ID permission.

**Rule:** Always gate Entra ID diagnostic settings behind a boolean variable (default `false`). Subscription-level roles (even Owner) don't grant tenant-level Entra ID permissions. Same pattern applies to Conditional Access policies and other tenant-scoped Entra resources.

### Lesson 10: Management group creation requires tenant-level permissions

**What happened:** Module 01-governance failed creating `azurerm_management_group` with 400 BadRequest — the user had Owner on the subscription but not write permission on the root management group.

**Fix:** Set `create_management_group = false` in terraform.tfvars. The variable and `count` guard already existed in the module.

**Rule:** Management group operations require explicit permissions at the management group level, not inherited from subscription roles. Always default `create_management_group` to `false` for lab environments. Document that users must have Management Group Contributor at the tenant root to use this feature.

### Lesson 11: Subscription policies may block storage account key-based auth

**What happened:** All three storage accounts in module 06 failed with `KeyBasedAuthenticationNotPermitted`. The MCAPS subscription has an Azure Policy enforcing Entra-only authentication. Terraform's AzureRM provider requires key access for data plane operations (creating containers, blobs, etc.).

**Fix:** Added `shared_access_key_enabled = true` to all `azurerm_storage_account` resources across modules 06, 08, 09, and 12. This explicitly opts in to key-based auth, overriding the subscription default.

**Rule:** Always set `shared_access_key_enabled = true` on storage accounts when Terraform needs to manage data plane resources (containers, blobs, file shares, queues). Corporate and MCAPS subscriptions often have policies disabling key auth by default. The Terraform provider cannot use Entra-only auth for data plane operations in older provider versions.

### Lesson 12: SQL Server and App Service provisioning is regionally blocked, not subscription-wide

**What happened:** Initially assumed SQL Server and App Service were blocked subscription-wide on MCAPS. User challenged the assumption. Probing multiple regions revealed SQL Server deploys fine in centralus, westus2, and northeurope — only eastus, eastus2, and westeurope were blocked. App Service had the same pattern — quota=0 was region-specific.

**Fix:** Deployed module 07 (databases) and module 09 (App Service, Functions) to centralus. Both deployed successfully. Cosmos DB also works in centralus.

**Rule:** When you get `ProvisioningDisabled` or quota=0 errors, don't assume it's subscription-wide. Probe 3-4 regions with quick CLI test deployments (`az sql server create`, `az appservice plan create`) to find a region that works. centralus and westus2 tend to have broader service availability than eastus for restricted subscriptions.

### Lesson 13: Function Apps with managed identity storage require role assignments

**What happened:** Function App failed creating a file share because the storage account had key auth disabled by subscription policy. Using `storage_account_access_key` is impossible when key auth is blocked.

**Fix:** Changed to `storage_uses_managed_identity = true` and added role assignments for `Storage Blob Data Owner` and `Storage File Data Privileged Contributor` on the function app's storage account.

**Rule:** In subscriptions that enforce Entra-only auth on storage accounts, use `storage_uses_managed_identity = true` on Function Apps instead of `storage_account_access_key`. Requires corresponding role assignments for the function app's managed identity.

### Lesson 14: Azure Migrate projects don't support eastus and require older API versions

**What happened:** `Microsoft.Migrate/migrateProjects` resource failed in eastus with `LocationNotAvailableForResourceType`. After moving to centralus, it failed again with `NoRegisteredProviderFound` for API version `2023-01-01`.

**Fix:** Changed location to `centralus` and API version to `2020-05-01` (the latest supported version). Also had to register `Microsoft.Migrate` provider first.

**Rule:** Azure Migrate has limited region support (no eastus) and uses older API versions. Check the error message for the list of supported regions and API versions. Always verify provider registration with `az provider show -n Microsoft.Migrate` before deploying.

### Lesson 15: Azure subscription policies cause persistent Terraform drift — fix config, don't fight policies

**What happened:** After deploying all 13 modules, `terraform plan` showed drift on every module. Three distinct patterns:
1. **`rg-class = "user-managed"` tag** — Azure automatically adds this tag to resource groups. Terraform sees it as unmanaged and wants to remove it.
2. **`allow_nested_items_to_be_public = false`** — subscription policy enforces this on storage accounts, but Terraform defaults to `true`.
3. **`local_authentication_enabled = false`** — subscription policy disables local (key-based) auth on Event Hubs, Service Bus, and Cosmos DB. Terraform defaults to `true`.
4. **`ftp_publish_basic_authentication_enabled` / `webdeploy_publish_basic_authentication_enabled`** — subscription policy disables these on App Service, Terraform defaults to `true`.
5. **Diagnostic settings `enabled_metric`** — Azure expands `AllMetrics` into individual category names (e.g., `Requests`, `SLI`, `Basic`), causing perpetual diff.

**Fix:**
- RG tags: `lifecycle { ignore_changes = [tags["rg-class"]] }` on all resource groups
- Storage: explicitly set `allow_nested_items_to_be_public = false`
- Event Hubs: `local_authentication_enabled = false`
- Service Bus: `local_auth_enabled = false`
- Cosmos DB: `local_authentication_disabled = true`
- App Service: `ftp_publish_basic_authentication_enabled = false`, `webdeploy_publish_basic_authentication_enabled = false`
- Diagnostic settings: `lifecycle { ignore_changes = [enabled_metric] }`

**Rule:** After deploying to a managed subscription, always run `terraform plan` and resolve all drift before considering deployment complete. Match Terraform config to subscription policy defaults — don't rely on Terraform defaults when policies override them. Use `lifecycle { ignore_changes }` for Azure-managed attributes that Terraform can't control (e.g., auto-added tags, metric category expansion).
