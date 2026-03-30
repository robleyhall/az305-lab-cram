# Module 09: Compute Solutions — Exercises

## Exercise 1: SSH to the VM and Check System Info
**Difficulty:** 🟢 Guided
**Method:** CLI
**Estimated Time:** 10 minutes

### Objective
Connect to a lab VM via SSH and inspect its configuration to understand how Azure VMs are provisioned and what metadata is available.

### Instructions
1. List VMs in the lab resource group:
   ```bash
   az vm list \
     --resource-group rg-az305-lab \
     --output table \
     --query "[].{Name:name, Size:hardwareProfile.vmSize, OS:storageProfile.osDisk.osType, Status:provisioningState}"
   ```
2. Get the public IP or use Azure Bastion:
   ```bash
   az vm list-ip-addresses \
     --resource-group rg-az305-lab \
     --output table
   ```
3. SSH into the VM:
   ```bash
   ssh azureuser@<public-ip>
   ```
4. Inside the VM, check system information:
   ```bash
   # CPU and memory
   lscpu | head -20
   free -h

   # Disk configuration
   lsblk
   df -h

   # Azure Instance Metadata Service (IMDS)
   curl -s -H "Metadata:true" "http://169.254.169.254/metadata/instance?api-version=2023-07-01" | jq '{compute: {vmSize, location, zone, name}, network}'
   ```
5. Check if the VM has a managed identity:
   ```bash
   curl -s -H "Metadata:true" "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https://management.azure.com/" | jq '{access_token: .access_token[:50], expires_on}'
   ```

### Success Criteria
- You can SSH into the VM and verify its size, OS, and disk configuration.
- You can query the Instance Metadata Service (IMDS) for VM details.
- You understand that IMDS provides identity tokens for managed identity authentication.

### Explanation
AZ-305 tests VM design decisions: size selection (compute, memory, storage optimized), disk types (Premium SSD, Standard SSD, Standard HDD, Ultra Disk), and networking. IMDS is important because it enables applications to discover their own identity and metadata without credentials. The exam tests when to use VMs vs. PaaS compute (App Service, Functions, AKS).

---

## Exercise 2: Browse to the Web App URL and Verify It Is Running
**Difficulty:** 🟢 Guided
**Method:** CLI
**Estimated Time:** 10 minutes

### Objective
Verify that an Azure App Service web application is running and inspect its configuration.

### Instructions
1. List App Service plans and web apps:
   ```bash
   az appservice plan list \
     --resource-group rg-az305-lab \
     --output table \
     --query "[].{Name:name, SKU:sku.name, Tier:sku.tier, Workers:sku.capacity}"
   ```
   ```bash
   az webapp list \
     --resource-group rg-az305-lab \
     --output table \
     --query "[].{Name:name, URL:defaultHostName, State:state, Runtime:siteConfig.linuxFxVersion}"
   ```
2. Get the URL and browse to it:
   ```bash
   az webapp show \
     --name <app-name> \
     --resource-group rg-az305-lab \
     --query "defaultHostName" --output tsv
   ```
   ```bash
   curl -s -o /dev/null -w "%{http_code}" https://<app-url>
   ```
3. Check the app's configuration:
   ```bash
   az webapp config show \
     --name <app-name> \
     --resource-group rg-az305-lab \
     --output json | jq '{alwaysOn, ftpsState, http20Enabled, minTlsVersion, vnetRouteAllEnabled}'
   ```
4. View application settings (environment variables):
   ```bash
   az webapp config appsettings list \
     --name <app-name> \
     --resource-group rg-az305-lab \
     --output table
   ```

### Success Criteria
- The web app responds with HTTP 200.
- You can identify the App Service plan tier and capacity.
- You understand the relationship between App Service plan (infrastructure) and web app (application).

### Explanation
App Service is a core AZ-305 compute option. The exam tests tier selection: Free/Shared (no SLA, shared infrastructure), Basic (dedicated, no scaling), Standard (auto-scale, staging slots), Premium (enhanced performance, VNet integration), and Isolated (App Service Environment, dedicated VNet). The exam expects you to choose the minimum tier that meets requirements. Always On, VNet integration, and deployment slots are common exam topics.

---

## Exercise 3: Scale the App Service Plan and Observe the Effect
**Difficulty:** 🟡 Intermediate
**Method:** CLI
**Estimated Time:** 20 minutes

### Objective
Scale an App Service plan both vertically (tier change) and horizontally (instance count) to understand scaling options.

### Instructions
1. Check the current scale settings:
   ```bash
   az appservice plan show \
     --name <plan-name> \
     --resource-group rg-az305-lab \
     --output json | jq '{sku: .sku, numberOfWorkers: .sku.capacity}'
   ```
2. Scale out (add instances):
   ```bash
   az appservice plan update \
     --name <plan-name> \
     --resource-group rg-az305-lab \
     --number-of-workers 3
   ```
3. Verify the scale-out:
   ```bash
   az appservice plan show \
     --name <plan-name> \
     --resource-group rg-az305-lab \
     --query "sku.capacity"
   ```
4. View auto-scale settings (if configured):
   ```bash
   az monitor autoscale list \
     --resource-group rg-az305-lab \
     --output table
   ```
5. Scale up (change tier) to observe the difference:
   ```bash
   az appservice plan update \
     --name <plan-name> \
     --resource-group rg-az305-lab \
     --sku P1V3
   ```
6. Scale back down when done to manage costs:
   ```bash
   az appservice plan update \
     --name <plan-name> \
     --resource-group rg-az305-lab \
     --sku B1 \
     --number-of-workers 1
   ```

### Success Criteria
- You can scale out (increase instance count) and verify the change.
- You can scale up (change SKU) and understand the performance difference.
- You understand that scale-out provides redundancy while scale-up provides more power per instance.

### Explanation
The exam tests scaling strategies. Scale up (vertical) = bigger instances, limited by maximum tier size. Scale out (horizontal) = more instances, requires stateless application design. Auto-scale uses metric-based rules (CPU, memory, HTTP queue length) to automatically adjust instance count. The exam expects you to design for horizontal scaling and recommend auto-scale for variable workloads. Key trap: scaling out requires session affinity or externalized session state.

---

## Exercise 4: Deploy a Custom Container to ACI
**Difficulty:** 🟡 Intermediate
**Method:** CLI
**Estimated Time:** 20 minutes

### Objective
Deploy a container to Azure Container Instances (ACI) to understand serverless container hosting.

### Instructions
1. Deploy a simple container:
   ```bash
   az container create \
     --resource-group rg-az305-lab \
     --name az305-test-container \
     --image mcr.microsoft.com/azuredocs/aci-helloworld \
     --dns-name-label az305-lab-$(date +%s) \
     --ports 80 \
     --cpu 1 \
     --memory 1.5 \
     --os-type Linux
   ```
2. Check the container status:
   ```bash
   az container show \
     --resource-group rg-az305-lab \
     --name az305-test-container \
     --output json | jq '{state: .containers[0].instanceView.currentState.state, ip: .ipAddress.ip, fqdn: .ipAddress.fqdn}'
   ```
3. View container logs:
   ```bash
   az container logs \
     --resource-group rg-az305-lab \
     --name az305-test-container
   ```
4. Test connectivity:
   ```bash
   curl http://$(az container show --resource-group rg-az305-lab --name az305-test-container --query "ipAddress.fqdn" --output tsv)
   ```
5. Clean up:
   ```bash
   az container delete \
     --resource-group rg-az305-lab \
     --name az305-test-container \
     --yes
   ```

### Success Criteria
- The container deploys and reaches a running state.
- You can access the application via the public IP/FQDN.
- You understand when to use ACI vs. AKS vs. App Service for containers.

### Explanation
ACI is tested on AZ-305 as a serverless container option. Use cases: batch processing, CI/CD build agents, sidecar containers, short-lived tasks. ACI provides fast startup (seconds), per-second billing, and no infrastructure management. However, it lacks orchestration features (scaling, rolling updates, service discovery). The exam expects you to choose ACI for simple, short-lived workloads, AKS for complex multi-container orchestration, and App Service for container for web workloads that benefit from PaaS features.

---

## Exercise 5: Examine Function App Configuration and Triggers
**Difficulty:** 🟡 Intermediate
**Method:** CLI
**Estimated Time:** 15 minutes

### Objective
Inspect an Azure Function App to understand its hosting plan, runtime, and trigger configuration.

### Instructions
1. List Function Apps in the resource group:
   ```bash
   az functionapp list \
     --resource-group rg-az305-lab \
     --output table \
     --query "[].{Name:name, Runtime:siteConfig.linuxFxVersion, State:state}"
   ```
2. View the Function App configuration:
   ```bash
   az functionapp show \
     --name <function-app-name> \
     --resource-group rg-az305-lab \
     --output json | jq '{name, state, kind, defaultHostName}'
   ```
3. Check the hosting plan type:
   ```bash
   az functionapp show \
     --name <function-app-name> \
     --resource-group rg-az305-lab \
     --output json | jq '.siteConfig'
   ```
4. List the functions within the app:
   ```bash
   az functionapp function list \
     --name <function-app-name> \
     --resource-group rg-az305-lab \
     --output table
   ```
5. View app settings to identify trigger connections:
   ```bash
   az functionapp config appsettings list \
     --name <function-app-name> \
     --resource-group rg-az305-lab \
     --output table
   ```

### Success Criteria
- You can identify the hosting plan: Consumption (serverless), Premium, or Dedicated (App Service plan).
- You can identify the runtime stack and version.
- You understand the trigger types (HTTP, Timer, Queue, Blob, Event Grid, etc.).

### Explanation
Azure Functions hosting plans are a key AZ-305 topic. Consumption plan: scales to zero, pay-per-execution, cold start latency, 5-minute default timeout (max 10). Premium plan: pre-warmed instances (no cold start), VNet integration, unlimited execution duration. Dedicated plan: runs on App Service plan, predictable cost, best for always-on workloads. The exam expects you to choose Consumption for sporadic workloads, Premium for latency-sensitive or VNet-required functions, and Dedicated when already paying for an App Service plan.

---

## Exercise 6: Redesign the Compute Architecture for High-Traffic Scenarios
**Difficulty:** 🔴 Challenge
**Method:** Conceptual
**Estimated Time:** 30 minutes

### Objective
Redesign a compute architecture that currently uses a single VM to handle high-traffic scenarios with auto-scaling, redundancy, and cost optimization.

### Instructions
The current architecture:
- Single B2s VM running a Node.js web application
- Application stores sessions in local memory
- Static files served from the VM
- Database connections made from the application

Redesign for:
- 99.95% availability
- Auto-scaling from 2 to 20 instances
- Zero-downtime deployments
- Cost optimization (don't pay for peak capacity 24/7)

Address:

1. **Compute platform selection:**
   - App Service vs. AKS vs. VM Scale Sets?
   - Justify your choice based on the workload characteristics.

2. **State management:**
   - Where do sessions go when you have multiple instances? (Redis Cache)
   - How do you handle file uploads? (Blob Storage)

3. **Static content:**
   - Azure CDN or Azure Front Door for static files?
   - How do you separate static from dynamic content?

4. **Auto-scaling strategy:**
   - Which metric to scale on? (CPU, HTTP queue, custom metric)
   - Scale-out rules and cool-down periods.
   - Scheduled scaling for predictable patterns.

5. **Deployment strategy:**
   - Blue-green with deployment slots (App Service)?
   - Rolling updates (AKS)?
   - How do you canary test new versions?

6. **Cost optimization:**
   - Reserved instances for baseline capacity.
   - Auto-scale for burst capacity.
   - Spot instances or savings plans?

### Success Criteria
- App Service with Standard or Premium tier is recommended for this workload.
- Session state is externalized to Redis Cache.
- Static files are served via CDN.
- Auto-scale rules are defined with appropriate thresholds and cool-down periods.
- Deployment slots enable zero-downtime deployment.

### Explanation
This is a classic AZ-305 compute modernization question. The exam expects you to migrate from VMs to PaaS when possible. App Service is the correct choice for most web applications because it provides built-in auto-scaling, deployment slots, managed SSL, and VNet integration. The key insight is that moving to PaaS requires externalizing state (sessions, file storage) because instances are ephemeral and can be replaced at any time.

---

## Exercise 7: Choose Compute Services for Variable Workload
**Difficulty:** 🔴 Challenge
**Method:** Conceptual
**Estimated Time:** 30 minutes

### Objective
**Scenario:** An application has 10 req/sec baseline, spikes to 10,000 req/sec during live events (weekly, 2-hour duration), processes background jobs (video transcoding, 5-30 minutes each), and sends email notifications. Budget is constrained.

Choose compute services for each workload component.

### Instructions
Design the compute architecture:

1. **Web API (10-10,000 req/sec):**
   - Which service handles this scale range?
   - How fast does it need to scale? (Minutes, not hours)
   - App Service Premium with auto-scale? AKS with HPA? Azure Container Apps?
   - Consider: KEDA (Kubernetes Event-Driven Autoscaling) for AKS.

2. **Background jobs (video transcoding):**
   - Long-running (5-30 minutes): rules out Consumption Functions (10-min timeout).
   - CPU-intensive: needs appropriately sized compute.
   - Options: ACI, AKS Jobs, Azure Batch, Premium Functions.
   - Cost model: pay only when jobs run.

3. **Email notifications:**
   - Short-lived, event-driven.
   - Azure Functions (Consumption plan): ideal for this workload.
   - Trigger: queue message or event.
   - SendGrid integration or Azure Communication Services.

4. **Event processing (during live events):**
   - How to decouple the API from background processing?
   - Queue-based load leveling: Service Bus or Storage Queue?
   - How to handle 10,000 messages/sec burst?

5. **Cost optimization:**
   - Calculate approximate monthly cost for each component.
   - Identify where Consumption/serverless saves money vs. always-on.
   - Reserved instances for baseline, pay-as-you-go for burst.

### Success Criteria
- Each workload component has a justified compute service selection.
- The web API handles the 1000x traffic spike within minutes.
- Background jobs use cost-effective, appropriately-timed compute.
- Email notifications use serverless (Functions) for cost efficiency.
- A queue decouples the API from background processing.

### Explanation
This tests the AZ-305 principle of "right service for the right workload." The exam expects you to decompose an application into components and select the optimal compute service for each. Common mistakes: using the same service for everything (over-engineering or under-serving), not considering cold start impact for latency-sensitive workloads, and not decoupling synchronous and asynchronous workloads. The correct answer almost always involves a mix of services.
