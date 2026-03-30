# Module 02: Identity & Access Management — Exercises

## Exercise 1: List Entra ID Groups and Their Members
**Difficulty:** 🟢 Guided
**Method:** CLI
**Estimated Time:** 10 minutes

### Objective
Enumerate Entra ID (Azure AD) groups and inspect their membership to understand the identity model in the lab environment.

### Instructions
1. List all Entra ID groups in your tenant:
   ```bash
   az ad group list --output table --query "[].{Name:displayName, Id:id, Type:groupTypes}"
   ```
2. Pick a group from the list and view its members:
   ```bash
   az ad group member list \
     --group "<group-display-name>" \
     --output table --query "[].{Name:displayName, UPN:userPrincipalName, Type:userType}"
   ```
3. Check if a specific user is a member of a group:
   ```bash
   az ad group member check \
     --group "<group-display-name>" \
     --member-id "<user-object-id>" \
     --output json
   ```
4. List the group's owners:
   ```bash
   az ad group owner list \
     --group "<group-display-name>" \
     --output table
   ```

### Success Criteria
- You can list all groups and identify security groups vs. Microsoft 365 groups.
- You can enumerate members of a specific group.
- You understand the difference between group members and group owners.

### Explanation
AZ-305 expects you to design identity solutions using Entra ID groups for RBAC assignments. The exam tests whether you understand that RBAC should be assigned to groups (not individual users) for scalability. Knowing how to verify group membership is essential for troubleshooting access issues.

---

## Exercise 2: Verify App Registration and Service Principal
**Difficulty:** 🟢 Guided
**Method:** CLI
**Estimated Time:** 10 minutes

### Objective
Inspect an existing app registration and its corresponding service principal to understand how applications authenticate to Azure resources.

### Instructions
1. List all app registrations in the tenant:
   ```bash
   az ad app list --output table \
     --query "[].{Name:displayName, AppId:appId, SignInAudience:signInAudience}"
   ```
2. View details of a specific app registration:
   ```bash
   az ad app show --id "<app-id>" --output json | jq '{displayName, appId, signInAudience, requiredResourceAccess}'
   ```
3. Find the corresponding service principal:
   ```bash
   az ad sp show --id "<app-id>" --output json | jq '{displayName, appId, servicePrincipalType}'
   ```
4. List the API permissions configured on the app:
   ```bash
   az ad app permission list --id "<app-id>" --output table
   ```
5. Check the consent status of permissions:
   ```bash
   az ad app permission list-grants --id "<app-id>" --output table
   ```

### Success Criteria
- You can distinguish between an app registration (identity definition) and a service principal (instance in a tenant).
- You can identify which API permissions the app has and whether they are admin-consented.
- You understand the relationship: App Registration → Service Principal → RBAC assignments.

### Explanation
The exam frequently tests the difference between app registrations and service principals. An app registration is the global definition of an application; a service principal is the local instance in a specific tenant. When designing multi-tenant applications or service-to-service authentication, you must understand this distinction. The exam also tests whether you know when admin consent is required (application permissions) vs. user consent (delegated permissions).

---

## Exercise 3: Add a User to a Group and Verify Role Inheritance
**Difficulty:** 🟡 Intermediate
**Method:** CLI
**Estimated Time:** 15 minutes

### Objective
Add a user to an Entra ID group that has Azure RBAC role assignments, then verify that the user inherits the expected permissions.

### Instructions
1. Identify a group that has an Azure RBAC role assignment on a resource group.
2. Create a test user (or use an existing one) and add them to the group.
3. Verify the user's effective Azure role assignments include the inherited role.
4. Test by performing an action the role allows (e.g., listing resources if the role is Reader).
5. Remove the user from the group and verify the role is revoked.

**Hints:**
- Use `az role assignment list --assignee <group-object-id>` to find group role assignments.
- Use `az ad group member add --group <group> --member-id <user-object-id>` to add the member.
- Role inheritance may take a few minutes to propagate.

### Success Criteria
- The user gains the RBAC role after being added to the group.
- The user can perform actions permitted by the role.
- After removal from the group, the user no longer has the role.

### Explanation
AZ-305 design principle: always assign RBAC to groups, never to individual users. This exercise demonstrates why — group-based access is easier to audit, scale, and revoke. The exam tests whether you'd recommend direct user assignments (wrong) or group-based assignments (correct) in enterprise scenarios.

---

## Exercise 4: Create a New App Registration with Specific API Permissions
**Difficulty:** 🟡 Intermediate
**Method:** CLI
**Estimated Time:** 20 minutes

### Objective
Create an app registration that represents a backend API service needing access to Microsoft Graph (read user profiles) and Azure Key Vault.

### Instructions
1. Create a new app registration:
   ```bash
   az ad app create \
     --display-name "az305-lab-api" \
     --sign-in-audience AzureADMyOrg
   ```
2. Note the `appId` from the output.
3. Add Microsoft Graph `User.Read.All` application permission:
   ```bash
   az ad app permission add \
     --id "<app-id>" \
     --api 00000003-0000-0000-c000-000000000000 \
     --api-permissions 1bfefb4e-e0b5-418b-a88f-73c46d2cc8e9=Role
   ```
4. Grant admin consent for the permissions.
5. Create the corresponding service principal.
6. Assign the service principal a role on the lab Key Vault (e.g., `Key Vault Secrets User`).
7. Verify the complete setup: app registration → service principal → RBAC role.

### Success Criteria
- The app registration exists with the correct API permissions.
- Admin consent is granted for application permissions.
- The service principal has the correct RBAC role on Key Vault.

### Explanation
This is a common exam pattern: a backend service needs to access both Microsoft Graph and Azure resources. The exam tests whether you know to use application permissions (not delegated) for service-to-service auth, and whether you'd use RBAC (correct) vs. Key Vault access policies (legacy) for Key Vault access control.

---

## Exercise 5: Design a Conditional Access Policy for the Organization
**Difficulty:** 🔴 Challenge
**Method:** Conceptual / Portal
**Estimated Time:** 25 minutes

### Objective
Design a set of Conditional Access policies for Contoso Ltd. with the following requirements:
- All users must use MFA when accessing Azure portal and Azure management endpoints.
- Privileged roles (Global Admin, User Admin) require MFA for all cloud app access.
- Users can bypass MFA when on the corporate network (trusted named location).
- Guest users can only access resources from managed devices.
- Legacy authentication protocols must be blocked entirely.

### Instructions
Design policies that address each requirement. For each policy, specify:
1. **Users and groups** — who is targeted and who is excluded.
2. **Cloud apps or actions** — what resources are protected.
3. **Conditions** — location, device state, client apps, risk level.
4. **Grant controls** — require MFA, require compliant device, block.
5. **Session controls** — if applicable.

Consider:
- Policy evaluation order (all policies are evaluated; most restrictive wins).
- Break-glass accounts — at least one Global Admin excluded from all CA policies.
- How to test in Report-Only mode before enforcing.

### Success Criteria
- At least 4-5 distinct Conditional Access policies are designed.
- Break-glass accounts are excluded from all policies.
- Legacy authentication is blocked with a dedicated policy.
- Policies don't create circular lockout conditions.
- A rollout plan includes Report-Only mode testing.

### Explanation
Conditional Access is a top-tested topic on AZ-305. The exam presents scenarios where you must select the right combination of conditions and controls. Key traps: forgetting break-glass accounts (could lock out all admins), not blocking legacy auth (bypasses MFA), and applying MFA to service accounts that can't perform interactive auth. The principle of least privilege applies — be specific about who, what, and when.

---

## Exercise 6: Design SSO from On-Premises AD to Azure Resources
**Difficulty:** 🔴 Challenge
**Method:** Conceptual
**Estimated Time:** 30 minutes

### Objective
**Scenario:** Contoso has 5,000 users in on-premises Active Directory. Users need single sign-on (SSO) to access both on-premises applications and Azure resources (portal, Azure SQL, SharePoint Online). Some users work remotely. The security team requires that passwords are never stored in the cloud.

Design the identity synchronization and SSO solution.

### Instructions
Address the following design decisions:

1. **Sync method selection:**
   - Entra Connect Sync vs. Entra Cloud Sync — which and why?
   - What are the trade-offs (features, complexity, agents)?

2. **Authentication method:**
   - Password Hash Sync (PHS) vs. Pass-Through Authentication (PTA) vs. Federation (AD FS)
   - The security team says "no passwords in the cloud" — does this rule out PHS?
   - What is the recommendation from Microsoft for most organizations?

3. **SSO mechanism:**
   - Seamless SSO — how does it work with PHS/PTA?
   - What about remote users not on the corporate network?

4. **High availability:**
   - How many PTA agents are recommended?
   - What happens if all PTA agents go offline?

5. **Hybrid identity features:**
   - Password writeback — when is it needed?
   - Device writeback — when is it needed?
   - Group writeback — what scenarios require it?

### Success Criteria
- A clear recommendation for sync method with justification.
- Authentication method addresses the "no passwords in cloud" requirement with a nuanced answer.
- SSO works for both on-network and remote users.
- The design is highly available (no single points of failure).
- Password writeback is enabled for self-service password reset.

### Explanation
This is a classic AZ-305 scenario. The exam tests nuanced understanding: PHS actually stores a hash-of-a-hash (not the password itself), and Microsoft recommends PHS as primary with PTA as an alternative when there is a strict regulatory requirement. PTA requires on-premises agents and has availability concerns. Federation (AD FS) is the most complex and is only recommended when you need features PHS/PTA don't support (e.g., smart card auth, third-party MFA). Always recommend PHS + Seamless SSO unless there's a specific reason not to.
