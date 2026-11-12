# Module 01: Governance & Compliance — Exercises

## Exercise 1: View Effective Policies on a Resource Group
**Difficulty:** 🟢 Guided
**Method:** CLI
**Estimated Time:** 10 minutes

### Objective
View the Azure Policy assignments that are in effect on a resource group to understand how governance controls cascade through the management hierarchy.

### Instructions
1. List all resource groups in your subscription:
   ```bash
   az group list --output table
   ```
2. Pick the lab resource group (e.g., `rg-az305-lab`) and list policy assignments scoped to it:
   ```bash
   az policy assignment list \
     --resource-group rg-az305-lab \
     --output table
   ```
3. For each assignment, note the `policyDefinitionId` and whether it is a built-in or custom policy.
4. View the full definition of one of the assigned policies:
   ```bash
   az policy definition show \
     --name "<policy-definition-name>" \
     --output json | jq '.policyRule'
   ```
5. Compare the effective policies at the resource group level with those at the subscription level:
   ```bash
   az policy assignment list --output table
   ```

### Success Criteria
- You can list all policy assignments on the resource group.
- You can explain the difference between a policy assignment at the subscription level vs. the resource group level.
- You can read and interpret the JSON policy rule of at least one assignment.

### Explanation
AZ-305 tests your ability to design governance solutions. Understanding how policies are inherited through management groups → subscriptions → resource groups is fundamental. The exam expects you to know that policies are additive (they accumulate down the hierarchy) and that deny effects at a higher scope cannot be overridden at a lower scope.

---

## Exercise 2: Check Policy Compliance State
**Difficulty:** 🟢 Guided
**Method:** CLI
**Estimated Time:** 10 minutes

### Objective
Query the compliance state of resources against assigned policies to identify non-compliant resources.

### Instructions
1. View the overall compliance summary for your subscription:
   ```bash
   az policy state summarize --output json | jq '.value[0].results'
   ```
2. List all non-compliant resources:
   ```bash
   az policy state list \
     --filter "complianceState eq 'NonCompliant'" \
     --output table
   ```
3. For a specific non-compliant resource, view the details:
   ```bash
   az policy state list \
     --resource-group rg-az305-lab \
     --filter "complianceState eq 'NonCompliant'" \
     --output json | jq '.[0]'
   ```
4. Trigger an on-demand compliance evaluation scan:
   ```bash
   az policy state trigger-scan --resource-group rg-az305-lab
   ```
5. Wait a few minutes and re-check compliance state to see if it has updated.

### Success Criteria
- You can view compliance summaries at subscription and resource group levels.
- You can identify specific non-compliant resources and the policies they violate.
- You understand the difference between an on-demand scan and the default periodic evaluation.

### Explanation
The exam frequently presents scenarios where you must recommend how to audit and enforce compliance. Knowing how to check compliance state is essential for troubleshooting and for designing remediation workflows. Azure Policy evaluates compliance roughly every 24 hours by default; on-demand scans are useful for immediate verification after changes.

---

## Exercise 3: Create a Custom Policy That Denies Public IP Creation
**Difficulty:** 🟡 Intermediate
**Method:** CLI
**Estimated Time:** 20 minutes

### Objective
Author a custom Azure Policy definition that prevents the creation of public IP address resources, then verify the definition is valid.

### Instructions
1. Create a JSON file for the policy rule that targets `Microsoft.Network/publicIPAddresses` with a `deny` effect.
2. Register the custom policy definition at the subscription level using `az policy definition create`.
3. Verify the definition appears in your subscription's policy definitions list.
4. Review the policy rule to ensure it uses the correct resource type and effect.

**Hints:**
- The `if` condition should check `"field": "type"` equals `"Microsoft.Network/publicIPAddresses"`.
- Use `"effect": "deny"` to block resource creation.
- Set the `mode` to `All`.

### Success Criteria
- The custom policy definition exists in your subscription.
- Running `az policy definition show --name <your-policy>` returns the correct rule.
- The policy rule JSON is syntactically correct and uses the deny effect.

### Explanation
AZ-305 expects you to know when to use built-in vs. custom policies. Custom policies are needed when built-in definitions don't cover your specific organizational requirement. Denying public IPs is a common security pattern — the exam tests whether you'd use a policy (preventive) vs. an alert (reactive) for this kind of control.

---

## Exercise 4: Assign the Custom Policy and Test It
**Difficulty:** 🟡 Intermediate
**Method:** CLI
**Estimated Time:** 20 minutes

### Objective
Assign the custom "deny public IP" policy to a resource group and verify that it blocks the creation of public IP addresses.

### Instructions
1. Assign the custom policy created in Exercise 3 to the lab resource group:
   ```bash
   az policy assignment create \
     --name "deny-public-ip-assignment" \
     --policy "<policy-definition-name>" \
     --resource-group rg-az305-lab \
     --display-name "Deny Public IP Creation"
   ```
2. Wait for the assignment to propagate (1-2 minutes).
3. Attempt to create a public IP address in the resource group:
   ```bash
   az network public-ip create \
     --name test-public-ip \
     --resource-group rg-az305-lab \
     --sku Basic
   ```
4. Observe the error message — it should indicate the request was denied by policy.
5. Verify that creating other resource types (e.g., a storage account) is not blocked.
6. Clean up: delete the policy assignment when done.

### Success Criteria
- The policy assignment is active on the resource group.
- Attempting to create a public IP returns a `RequestDisallowedByPolicy` error.
- Other resource types are unaffected by the policy.

### Explanation
Testing policies in a scoped environment before applying broadly is a best practice the exam expects you to recommend. The exam may present scenarios where a policy is too broad or too narrow — understanding how to test assignments at the resource group level before promoting to subscription or management group is a key design skill.

---

## Exercise 5: Design a Management Group Hierarchy for a Multi-Team Organization
**Difficulty:** 🔴 Challenge
**Method:** Conceptual / Whiteboard
**Estimated Time:** 30 minutes

### Objective
Design a management group hierarchy for Contoso Ltd., which has the following organizational structure:
- **Corporate IT** — manages shared infrastructure (networking, identity)
- **Product Engineering** — 3 product teams, each with dev/staging/prod environments
- **Data & Analytics** — separate compliance requirements (PCI-DSS)
- **Sandbox** — developer experimentation, limited budget

### Instructions
Design a management group tree that addresses:
1. Policy inheritance — production workloads must have stricter controls than sandbox.
2. Cost management — each product team needs independent cost tracking.
3. Compliance — the Data & Analytics team needs PCI-DSS policies applied without affecting other teams.
4. Access control — Corporate IT needs read access everywhere, but product teams should only see their own subscriptions.

Deliverables:
- Draw (or describe in text) the management group hierarchy.
- For each management group, list which policies and RBAC roles you would assign.
- Explain why you chose this structure over alternatives.

### Success Criteria
- The hierarchy separates production from non-production workloads.
- PCI-DSS policies are scoped to only the Data & Analytics management group.
- Sandbox subscriptions have budget alerts and resource type restrictions.
- Corporate IT has Reader role at the root management group.
- Each product team's subscriptions are isolated from each other.

### Explanation
AZ-305 heavily tests management group design. The key principle is that policies and RBAC flow downward and are additive. A well-designed hierarchy avoids the need for policy exemptions. Common exam traps: placing all subscriptions under a single management group (no separation of concerns), or applying PCI-DSS policies at the root (affects everything unnecessarily).

---

## Exercise 6: Implement Organization-Wide Tag Enforcement
**Difficulty:** 🔴 Challenge
**Method:** CLI / Conceptual
**Estimated Time:** 30 minutes

### Objective
**Scenario:** Your organization needs to ensure all resources in production subscriptions have a `CostCenter` tag. Resources without this tag should not be deployable. Additionally, resource groups should inherit tags to child resources automatically.

Design and implement (or describe) a complete solution.

### Instructions
Consider and address:
1. **Which policy effect** prevents resource creation without the tag? (`deny` vs. `audit` vs. `modify`)
2. **Where to assign** the policy — management group, subscription, or resource group?
3. **Tag inheritance** — how do you ensure child resources inherit the `CostCenter` tag from their resource group? (Hint: there's a built-in policy for this.)
4. **Existing resources** — how do you remediate resources that already exist without the tag?
5. **Exemptions** — some resource types (e.g., managed identities) don't support tags. How do you handle this?

Deliverables:
- A policy assignment strategy (what policies, where assigned, what effects).
- A remediation plan for existing non-compliant resources.
- An explanation of how tag inheritance works with the `modify` effect and remediation tasks.

### Success Criteria
- New resources without `CostCenter` are blocked in production.
- Existing resources are remediated via a remediation task.
- Child resources automatically inherit `CostCenter` from their resource group.
- Resource types that don't support tags are handled gracefully (exemptions or `mode: Indexed`).

### Explanation
Tag enforcement is one of the most common AZ-305 governance scenarios. The exam tests whether you know the difference between `deny` (preventive), `audit` (visibility only), and `modify` (auto-remediate). The correct answer typically combines `deny` for new resources and `modify` with a remediation task for existing resources. Tag inheritance uses the built-in "Inherit a tag from the resource group if missing" policy with the `modify` effect.
