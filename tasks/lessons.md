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
