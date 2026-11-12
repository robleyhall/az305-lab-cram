# Module 04: Monitoring & Logging — Exercises

## Exercise 1: Run a KQL Query in Log Analytics
**Difficulty:** 🟢 Guided
**Method:** CLI / Portal
**Estimated Time:** 10 minutes

### Objective
Execute Kusto Query Language (KQL) queries against a Log Analytics workspace to retrieve and analyze log data.

### Instructions
1. Identify the Log Analytics workspace in the lab:
   ```bash
   az monitor log-analytics workspace list \
     --resource-group rg-az305-lab \
     --output table
   ```
2. Run a simple KQL query to list recent heartbeats:
   ```bash
   az monitor log-analytics query \
     --workspace <workspace-id> \
     --analytics-query "Heartbeat | summarize count() by Computer | order by count_ desc" \
     --output table
   ```
3. Query for recent activity log events:
   ```bash
   az monitor log-analytics query \
     --workspace <workspace-id> \
     --analytics-query "AzureActivity | where TimeGenerated > ago(1h) | project TimeGenerated, OperationName, ActivityStatus, Caller | order by TimeGenerated desc | take 20" \
     --output table
   ```
4. Try a query that uses the `summarize` operator to count events by category:
   ```bash
   az monitor log-analytics query \
     --workspace <workspace-id> \
     --analytics-query "AzureActivity | where TimeGenerated > ago(24h) | summarize EventCount=count() by CategoryValue | order by EventCount desc" \
     --output table
   ```

### Success Criteria
- You can run KQL queries against the workspace and get results.
- You understand the basic KQL operators: `where`, `project`, `summarize`, `order by`, `take`.
- You can filter events by time range using `ago()`.

### Explanation
KQL is not deeply tested on AZ-305 (it is more of an AZ-104/AZ-400 topic), but you need to know that Log Analytics uses KQL, that data is organized into tables (Heartbeat, AzureActivity, Perf, etc.), and that you can query across multiple workspaces. The exam tests workspace design decisions more than query syntax.

---

## Exercise 2: View Configured Alerts and Action Groups
**Difficulty:** 🟢 Guided
**Method:** CLI
**Estimated Time:** 10 minutes

### Objective
Inspect the alert rules and action groups configured in the lab to understand the monitoring pipeline.

### Instructions
1. List all metric alert rules in the resource group:
   ```bash
   az monitor metrics alert list \
     --resource-group rg-az305-lab \
     --output table
   ```
2. View details of a specific alert rule:
   ```bash
   az monitor metrics alert show \
     --name <alert-name> \
     --resource-group rg-az305-lab \
     --output json | jq '{name, severity, criteria: .criteria, actions}'
   ```
3. List all action groups in the resource group:
   ```bash
   az monitor action-group list \
     --resource-group rg-az305-lab \
     --output table
   ```
4. View the details of an action group (notification channels):
   ```bash
   az monitor action-group show \
     --name <action-group-name> \
     --resource-group rg-az305-lab \
     --output json | jq '{emailReceivers, smsReceivers, webhookReceivers}'
   ```
5. Understand the alert pipeline: Alert Rule evaluates condition, triggers Action Group, sends notifications.

### Success Criteria
- You can list all alert rules and their severity levels.
- You can identify which action groups are attached to each alert.
- You understand the notification channels configured (email, SMS, webhook, Logic App, etc.).

### Explanation
AZ-305 tests monitoring design. Alerts follow a pipeline: metric/log data, then alert rule (condition), then action group (response). The exam expects you to know that action groups are reusable across multiple alert rules, that severity levels range from 0 (Critical) to 4 (Verbose), and that you can use ITSM connectors to integrate with tools like ServiceNow.

---

## Exercise 3: Create a Custom Metric Alert for a Resource
**Difficulty:** 🟡 Intermediate
**Method:** CLI
**Estimated Time:** 20 minutes

### Objective
Create a metric alert that fires when a specific resource exceeds a threshold, demonstrating proactive monitoring.

### Instructions
1. Choose a target resource (e.g., a VM) and list its available metrics:
   ```bash
   az monitor metrics list-definitions \
     --resource <resource-id> \
     --output table --query "[].{Name:name.value, Unit:unit, AggregationType:primaryAggregationType}"
   ```
2. Create an action group for the alert (or use an existing one):
   ```bash
   az monitor action-group create \
     --name "az305-lab-alerts" \
     --resource-group rg-az305-lab \
     --short-name "labAlerts" \
     --action email admin-email your-email@example.com
   ```
3. Create a metric alert rule (e.g., CPU > 80% for 5 minutes):
   ```bash
   az monitor metrics alert create \
     --name "high-cpu-alert" \
     --resource-group rg-az305-lab \
     --scopes <resource-id> \
     --condition "avg Percentage CPU > 80" \
     --window-size 5m \
     --evaluation-frequency 1m \
     --severity 2 \
     --action-group <action-group-id> \
     --description "Alert when average CPU exceeds 80% for 5 minutes"
   ```
4. Verify the alert rule is active:
   ```bash
   az monitor metrics alert show \
     --name "high-cpu-alert" \
     --resource-group rg-az305-lab \
     --output json | jq '{isEnabled, severity, criteria}'
   ```

### Success Criteria
- The alert rule is created and enabled.
- The alert targets the correct resource and metric.
- The action group is properly linked.
- You understand the relationship between window size, evaluation frequency, and alert sensitivity.

### Explanation
The exam tests when to use metric alerts vs. log alerts. Metric alerts evaluate numeric thresholds on platform metrics (CPU, memory, requests) and have near-real-time evaluation (1 minute). Log alerts use KQL queries against Log Analytics and have a minimum 5-minute evaluation frequency. For simple threshold monitoring, metric alerts are preferred. For complex multi-condition analysis, log alerts are appropriate.

---

## Exercise 4: Build a Log Analytics Query to Find All Failed Operations
**Difficulty:** 🟡 Intermediate
**Method:** CLI / Portal
**Estimated Time:** 20 minutes

### Objective
Write KQL queries that identify failed operations across Azure resources, a common troubleshooting and auditing task.

### Instructions
1. Query for failed Azure Activity Log operations in the last 24 hours:
   ```kql
   AzureActivity
   | where TimeGenerated > ago(24h)
   | where ActivityStatusValue == 'Failure' or ActivityStatusValue == 'Failed'
   | project TimeGenerated, OperationNameValue, ActivityStatusValue, Caller, ResourceGroup, _ResourceId
   | order by TimeGenerated desc
   ```
2. Summarize failures by operation type:
   ```kql
   AzureActivity
   | where TimeGenerated > ago(24h)
   | where ActivityStatusValue has "Fail"
   | summarize FailureCount=count() by OperationNameValue
   | order by FailureCount desc
   | take 10
   ```
3. Find the top callers (users/service principals) generating failures:
   ```kql
   AzureActivity
   | where TimeGenerated > ago(24h)
   | where ActivityStatusValue has "Fail"
   | summarize FailureCount=count() by Caller
   | order by FailureCount desc
   | take 10
   ```
4. Optionally, create a log-based alert rule for this query using the portal for easier configuration.

### Success Criteria
- You can identify failed operations and their frequency.
- You can determine which users or service principals are causing failures.
- You understand how to convert a KQL query into a log alert rule.

### Explanation
AZ-305 scenarios often include "how would you detect and alert on unauthorized or failed operations?" The answer combines Log Analytics (for querying) with log alert rules (for automation). The exam tests whether you would send Activity Logs to a Log Analytics workspace (correct, as it enables KQL querying and alerting) vs. only using the Activity Log blade (limited retention and no custom alerting).

---

## Exercise 5: Design a Monitoring Solution for a Multi-Tier Application
**Difficulty:** 🔴 Challenge
**Method:** Conceptual
**Estimated Time:** 30 minutes

### Objective
Design a comprehensive monitoring strategy for a three-tier application (web front-end, API tier, database) running on Azure.

### Instructions
Design the monitoring solution addressing:

1. **Application performance monitoring:**
   - Which service provides request tracing, dependency maps, and failure analysis?
   - How do you correlate requests across tiers (distributed tracing)?
   - What is the role of the Application Insights SDK vs. auto-instrumentation?

2. **Infrastructure monitoring:**
   - VM metrics (CPU, memory, disk): which Azure Monitor feature collects these?
   - How do you get guest OS-level metrics (e.g., available memory) vs. host-level metrics?
   - What agent is needed for VM insights?

3. **Log aggregation:**
   - Should each tier have its own Log Analytics workspace or share one?
   - What are the cost implications of workspace design?
   - How do you query across multiple workspaces?

4. **Alert strategy:**
   - Define alert rules for each tier (at least 2 per tier).
   - What severity levels would you assign?
   - How do you avoid alert fatigue?

5. **Dashboards and visualization:**
   - Azure Monitor Workbooks vs. Azure Dashboard vs. Grafana: when to use each?
   - How do you provide different views for operations team vs. developers?

### Success Criteria
- Application Insights is used for application-level monitoring with distributed tracing.
- Azure Monitor Agent (AMA) is used for VM-level metrics and logs.
- A workspace design decision is made with cost justification.
- Alert rules cover key failure scenarios without being overly noisy.
- Visualization strategy serves different stakeholder needs.

### Explanation
AZ-305 frequently presents multi-tier monitoring scenarios. The key services: Application Insights (app-level, distributed tracing), Azure Monitor Agent (infrastructure), Log Analytics (log aggregation and querying). The workspace design question is critical: a single workspace simplifies cross-resource queries but may have cost/regulatory implications; multiple workspaces add complexity but enable data sovereignty and cost splitting. The exam favors a single workspace unless there is a specific reason to separate.

---

## Exercise 6: Design Centralized Monitoring for Multi-Subscription VMs
**Difficulty:** 🔴 Challenge
**Method:** Conceptual
**Estimated Time:** 30 minutes

### Objective
**Scenario:** You need to monitor 50 VMs across 5 subscriptions with centralized alerting. VMs run a mix of Windows and Linux. The operations team needs a single dashboard to see all VM health. Compliance requires 90 days of log retention. Budget is constrained.

Design the workspace architecture and alert strategy.

### Instructions
Address these design decisions:

1. **Workspace topology:**
   - Single centralized workspace vs. one per subscription vs. hybrid?
   - What are the cost implications of cross-subscription data ingestion?
   - How does data residency affect workspace placement?

2. **Data collection:**
   - Azure Monitor Agent (AMA): how do you deploy to 50 VMs efficiently?
   - Data Collection Rules (DCR): how do you configure what data is collected?
   - How do you minimize cost by collecting only necessary data?

3. **Alert strategy:**
   - How do you create alerts that apply to all 50 VMs without creating 50 individual rules?
   - What is a resource-centric alert vs. a workspace-centric alert?
   - How do you route alerts to different teams based on subscription?

4. **Retention and archival:**
   - Interactive retention vs. archive tier: what are the cost differences?
   - How do you meet the 90-day compliance requirement cost-effectively?
   - What is the default retention period and how do you change it?

5. **Dashboard:**
   - Design a single-pane-of-glass dashboard showing VM health across all subscriptions.
   - What Azure Monitor Workbook features would you use?

### Success Criteria
- A single centralized workspace is recommended (with justification for when to split).
- AMA deployment uses Azure Policy for at-scale deployment.
- Alert rules use resource group or subscription scope to cover multiple VMs.
- Retention is configured to 90 days interactive, with optional archive for cost savings.
- The dashboard uses Azure Monitor Workbooks with subscription parameter selectors.

### Explanation
This is a common AZ-305 design question. The key insights: (1) A single workspace is almost always the right answer for centralized monitoring unless regulatory requirements force data separation. (2) AMA replaces the legacy Log Analytics agent (MMA) and should always be recommended. (3) Data Collection Rules (DCRs) are the modern way to configure what data flows to which workspace. (4) Default Log Analytics retention is 30 days; you can extend up to 730 days interactively or use the archive tier for long-term, cheaper storage with slower query performance.
