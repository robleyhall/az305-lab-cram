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

### Lesson 15: Azure Policy can silently change your Terraform resources

**What happened:** After deploying all 13 modules, `terraform plan` showed drift on every module — settings we never changed were different from what our Terraform declared. Hours later, more drift appeared: policy remediation tasks disabled public network access on storage accounts and Key Vault while we were working on other modules.

**Why it happened:** Azure Policy has effects that change resources without Terraform knowing:

| Policy Effect | What it does | When | Example |
|---|---|---|---|
| **Audit** | Reports non-compliance. Changes nothing. | — | "Flag storage accounts without HTTPS" |
| **Deny** | Blocks the deployment request. | At deploy time | "Reject VMs outside allowed regions" |
| **Modify / Append** | Changes settings during deployment. Terraform requests one value; Azure applies a different one. | At deploy time | "Force `allowSharedKeyAccess = false` on all storage accounts" |
| **DeployIfNotExists (DINE)** | Creates or changes related resources after deployment succeeds. Remediation tasks can also run on a schedule against existing resources. | After deploy, or async | "Add a diagnostic setting to every Key Vault" |

The first two (Audit, Deny) are straightforward — one is informational, the other blocks you with a clear error. The last two (Modify, DINE) are the source of drift: they change resources behind Terraform's back.

**The perpetual-drift trap:** If your Terraform says `public_network_access_enabled = true` but a Modify policy forces it to `false` at creation time, you get a loop:
1. `terraform plan` sees a diff — config says `true`, Azure says `false`
2. `terraform apply` sends `true` to Azure
3. Modify policy intercepts and sets `false`
4. Next `terraform plan` shows the same diff again

This repeats forever. The fix is not to fight the policy — it's to declare the value the policy enforces.

**The correct approach — read, don't probe:**

We initially built a profiler (`prerequisites/profile-subscription.sh`) that created temporary resources to discover what policies changed. This was useful for learning what our subscription enforced, but it's the wrong model for a finished artifact:

- It's invasive — creates real resources to detect behavior
- It's incomplete — only probes for specific policies we thought to test
- It's fragile — detection logic must be updated whenever new policies are added
- It gives false confidence — our audit found that 9 of 11 generated variables were never consumed by any module

The better approach is to **read policy assignments directly** using read-only APIs:

```bash
# Read all policy assignments affecting the subscription
az policy assignment list --query "[].{name:displayName, effect:parameters.effect.value}" --output table

# Read a specific policy definition to see its effect and conditions
az policy definition show --name <policy-name> --query "{effect:policyRule.then.effect, conditions:policyRule.if}"
```

This is read-only, complete, and deterministic. You can see every active policy, its effect, and its conditions without creating anything.

**What the profiler should become:** A read-only compatibility check that:
1. Lists policy assignments on the subscription (read-only)
2. Identifies Deny, Modify, and DINE effects and what they enforce
3. Checks VM SKU availability and regional service restrictions (already read-only)
4. Writes the results to `subscription-profile.env` as `TF_VAR_` exports
5. Presents clear, plain-English output: "Your subscription enforces X, so the lab will use Y"

**What we got wrong in the implementation:**

An audit of the current codebase found significant gaps between the profiler and the modules:

| Profiler generates | Used by modules? | What actually happens |
|---|---|---|
| `vm_size` | ✅ Modules 05, 09, 12 | Properly wired through variables |
| `appservice_location` | ✅ Module 09 | Properly wired through variables |
| `sql_location` | ❌ Not referenced | SQL location hardcoded elsewhere |
| `storage_shared_key_enabled` | ❌ Not referenced | Hardcoded `false` in module 06 |
| `storage_allow_public_access` | ❌ Not referenced | Hardcoded `false` in module 06 |
| `storage_use_azuread` | ❌ Not referenced | Hardcoded `true` in module 09 |
| `eventhub_local_auth_enabled` | ❌ Not referenced | No module consumes this |
| `servicebus_local_auth_enabled` | ❌ Not referenced | No module consumes this |
| `cosmosdb_local_auth_disabled` | ❌ Not referenced | No module consumes this |

The profiler detected constraints, but the modules mostly hardcode the values anyway. This means the profiler adds complexity without delivering portability.

**When `ignore_changes` is appropriate:**
- ✅ Platform metadata that doesn't affect behavior: `tags["rg-class"]` (Azure auto-classification), `enabled_metric` (representational expansion), `ip_tags` (platform tagging)
- ❌ Security-meaningful settings: auth, network access, encryption. If policy enforces a value, declare it in Terraform. Don't hide the mismatch with `ignore_changes`.

**Rules:**

1. Before writing Terraform for a new subscription, run `az policy assignment list` and read what's enforced. Don't discover it through deployment failures.
2. If a policy enforces a setting, declare that value in your Terraform config. A config that asks for something the platform will never allow is a bug.
3. Keep the subscription profiler, but make it read-only. No probe resources. Use `az policy assignment list`, `az vm list-skus`, and `az provider list`.
4. Every variable the profiler generates must be consumed by at least one module. Don't detect things you won't use.
5. Deploy scripts should validate that the subscription profile exists before running `terraform apply`.
6. Use `ignore_changes` only on non-semantic attributes. Each use should have an inline comment explaining why the attribute is noise, not signal.

### Lesson 16: Terraform auto.tfvars only loads from the working directory

**What happened:** The profiler wrote `subscription-profile.auto.tfvars` to `modules/`, but each module runs terraform from its own subdirectory (e.g., `modules/06-storage/`). Terraform only auto-loads `.auto.tfvars` from the current working directory — not parent directories. So the profile was never loaded. The 2 variables that "worked" (`vm_size`, `appservice_location`) had been manually copied into each module's `terraform.tfvars`.

**Fix:** Replaced the `.auto.tfvars` approach with a `.env` file that exports `TF_VAR_` environment variables. The deploy script sources it before running terraform. Environment variables for undeclared variables are silently ignored, so each module only declares the profile variables it uses.

**Rule:** Don't put `.auto.tfvars` in a parent directory and assume child modules will load it — they won't. For cross-module variable sharing, use either `TF_VAR_` environment variables (silently ignored when undeclared) or explicit `-var-file` paths. If using `-var-file`, every variable in the file must be declared by the target module or Terraform will error.

### Lesson 17: Recovery Services vault soft-delete blocks teardown

**What happened:** `terraform destroy` on module 05-ha-dr failed because the Recovery Services vault had VM backup items in soft-deleted state. MCAPS subscription policy prevents disabling soft-delete on vaults (`BMSUserErrorDisablingSoftDeleteStateNotAllowed`).

**Fix:** Undelete the backup items (`az backup protection undelete`), wait for propagation, then delete backup data (`az backup protection disable --delete-backup-data true`). If the vault still won't delete, force-delete the resource group with `az group delete` and clear terraform state manually with `terraform state rm`.

**Rule:** Before destroying modules with Recovery Services vaults, unregister all backup items and purge backup data. The sequence is: (1) undelete soft-deleted items, (2) wait 15–30s for propagation, (3) disable protection with `--delete-backup-data true`, (4) then destroy. If the subscription blocks disabling soft-delete, force-delete the RG and clear state.

### Lesson 18: Azure auto-creates NSGs and alert rules that block RG deletion

**What happened:** Three resource groups (foundation, monitoring, networking) couldn't be deleted by `terraform destroy` because Azure had auto-created resources that Terraform didn't manage — per-subnet NSGs (`*-nsg-eastus`) and Application Insights Smart Detection alert rules. Terraform's destroy saw an empty state but the RGs still had sub-resources.

**Fix:** Force-deleted the RGs with `az group delete` and cleared terraform state with `terraform state rm`.

**Rule:** Azure auto-creates NSGs for subnets and alert rules for Application Insights. These aren't managed by Terraform and will block RG deletion during teardown. For clean teardown scripts, add `az group delete --yes --no-wait` as a fallback after `terraform destroy`, or use `lifecycle { ignore_changes }` patterns that also handle sub-resource cleanup.

### Lesson 19: Resource locks must be destroyed before locked resources

**What happened:** Module 01-governance destroy failed with `ScopeLocked` because the CanNotDelete lock on the RG prevented policy assignment deletion. Terraform tried to delete the policy assignment before deleting the lock.

**Fix:** Retried `terraform destroy` — the lock had been deleted on the first attempt but the destroy errored mid-way. The retry completed successfully.

**Rule:** Terraform usually handles lock deletion order correctly, but if a destroy fails mid-way due to timing, retry. The lock is typically deleted first, and the retry will find it already gone and proceed with the remaining resources.
