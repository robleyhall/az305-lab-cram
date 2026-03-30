# Module 09 — Compute Solutions

> **AZ-305 Exam Weight: 30–35%** — Design Infrastructure Solutions is the largest domain on the exam. Compute is the core of this domain. Expect 15–20 questions on choosing the right compute service, sizing VMs, understanding App Service tiers, and comparing container options.

## What This Module Creates

| Resource | Name Pattern | Purpose |
|---|---|---|
| Resource Group | `az305-lab-compute-rg` | Isolated container for all compute resources |
| Linux VM | `az305-lab-vm-linux` | IaaS compute — full OS control, lift-and-shift |
| Network Interface | `az305-lab-nic-vm-linux` | VM connectivity to compute subnet (10.0.5.0/24) |
| Storage Account | `az305-labbootdiag<suffix>` | VM boot diagnostics storage |
| App Service Plan | `az305-lab-asp` | Linux B1 plan for web app hosting |
| Web App | `az305-lab-webapp-<suffix>` | PaaS compute — Node.js 20 LTS, managed platform |
| Container Instance | `az305-lab-aci` | Serverless container — nginx demo |
| Container Registry | `az305-labacr<suffix>` | Private Docker image registry (Basic tier) |
| Function App | `az305-lab-func-<suffix>` | Serverless compute — Python 3.11 on Consumption |
| Service Plan (Y1) | `az305-lab-func-asp` | Consumption plan for Function App |
| Storage Account | `az305-labfuncsa<suffix>` | Function App required storage |
| Application Insights | `az305-lab-func-appinsights` | Function App telemetry and monitoring |
| Batch Account | `az305-labbatch<suffix>` | Large-scale parallel / HPC workloads |
| Storage Account | `az305-labbatchsa<suffix>` | Batch account auto-storage |
| SSH Key | (generated) | tls_private_key for VM access |

## Prerequisites

- **Module 00 (Foundation)** deployed — provides VNet, compute subnet, Log Analytics workspace
- Azure CLI authenticated (`az login`)
- Terraform >= 1.5.0

## Deploy

```bash
cd az305-lab/modules/09-compute

# 1. Copy and fill in variables
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with Module 00 output values:
#   cd ../00-foundation && terraform output

# 2. Initialize and deploy
terraform init
terraform plan -out=tfplan
terraform apply tfplan

# 3. Verify resources
terraform output webapp_url        # Visit in browser
terraform output aci_ip_address    # curl http://<ip> for nginx
terraform output acr_login_server  # Docker registry endpoint
terraform output function_app_url  # Function App endpoint

# 4. Get SSH key for VM access (if needed)
terraform output -raw ssh_private_key_pem > ~/.ssh/az305-vm.pem
chmod 600 ~/.ssh/az305-vm.pem
# ssh -i ~/.ssh/az305-vm.pem azureadmin@<vm-private-ip>
# (requires VPN or bastion to reach private IP)
```

## Destroy

```bash
terraform destroy
# Estimated time: ~5 minutes
# All resources in az305-lab-compute-rg will be removed
```

## Azure Compute Decision Tree (CRITICAL for AZ-305)

```
┌─ "Full OS control / legacy software / lift-and-shift"
│   └─► Virtual Machines (IaaS)
│
├─ "Host a web app or API with minimal ops"
│   └─► App Service (PaaS)
│       ├─ Code → Standard App Service
│       └─ Container → App Service for Containers
│
├─ "Run containers without managing infrastructure"
│   ├─ Simple (1–5 containers) → ACI
│   └─ Complex (microservices) → AKS
│
├─ "Event-driven / execute on trigger"
│   └─► Azure Functions (Serverless)
│
├─ "Massive parallel processing / HPC"
│   └─► Azure Batch
│
└─ "Scheduled background jobs"
    ├─ Simple → Functions Timer trigger
    └─ Parallel → Azure Batch
```

### VM Sizing Families

| Series | Type | Use Case |
|---|---|---|
| B | Burstable | Dev/test, low-traffic web servers |
| D | General purpose | Production apps, balanced CPU/memory |
| E | Memory optimized | SAP HANA, caches, in-memory analytics |
| F | Compute optimized | Batch processing, gaming, modeling |
| L | Storage optimized | Big data, NoSQL, data warehousing |
| M | Memory (extreme) | SAP HANA large instances |
| N | GPU | ML training, rendering, HPC |
| H | High performance | Fluid dynamics, FEA, seismic analysis |

### App Service Tiers

| Tier | Scale Out | Key Features |
|---|---|---|
| Free (F1) | — | 60 CPU min/day, no custom domain |
| Shared (D1) | — | Custom domains, no SSL/scale |
| Basic (B1-B3) | 3 instances | Dedicated VMs, SSL, Always On |
| Standard (S1-S3) | 10 instances | Deployment slots, auto-scale, VNet integration |
| Premium v3 (P1-P3) | 30 instances | Zone redundancy, enhanced performance |
| Isolated v2 (I1-I6) | 100 instances | ASE, full VNet isolation |

### Functions Hosting Plans

| Plan | Cold Start | Max Duration | Scale | VNet |
|---|---|---|---|---|
| Consumption (Y1) | Yes (1–10s) | 10 min | 0 → 200 instances | No |
| Premium (EP1-EP3) | No (pre-warmed) | Unlimited | KEDA-based | Yes |
| Dedicated | No (Always On) | Unlimited | Manual/auto | Yes |

### Container Options

| Feature | ACI | AKS | App Service |
|---|---|---|---|
| Orchestration | None | Full K8s | App Service |
| Startup time | ~30s | Minutes (pod) | Minutes |
| Scaling | Manual | HPA + Cluster | App Service rules |
| Best for | Batch jobs, demos | Microservices | Containerized web apps |
| Cost model | Per-second | Node VMs | App Service Plan |

## Inputs

| Variable | Type | Default | Description |
|---|---|---|---|
| `location` | `string` | `"eastus"` | Azure region |
| `prefix` | `string` | `"az305-lab"` | Naming prefix |
| `foundation_resource_group_name` | `string` | — | Foundation RG name (required) |
| `vnet_id` | `string` | — | Foundation VNet resource ID (required) |
| `compute_subnet_id` | `string` | — | Compute subnet resource ID (required) |
| `log_analytics_workspace_id` | `string` | — | Log Analytics workspace ID (required) |
| `admin_ssh_public_key` | `string` | `""` | SSH public key (auto-generated if empty) |
| `tags` | `map(string)` | Lab defaults | Resource tags |

## Outputs

| Output | Description |
|---|---|
| `resource_group_name` | Compute resource group name |
| `vm_id` | Linux VM resource ID |
| `vm_private_ip` | VM private IP on compute subnet |
| `webapp_url` | Web App HTTPS URL |
| `webapp_name` | Web App name |
| `aci_ip_address` | ACI public IP address |
| `acr_login_server` | Container Registry login URL |
| `function_app_url` | Function App HTTPS URL |
| `function_app_name` | Function App name |
| `batch_account_name` | Batch account name |
| `ssh_private_key_pem` | Generated SSH private key (sensitive) |

## Dependencies

- **Module 00 (Foundation)**: VNet, compute subnet, Log Analytics workspace
- **Module 04 (Monitoring)**: Optional — this module creates its own Application Insights

## Estimated Cost

| Resource | Daily Cost | Notes |
|---|---|---|
| VM (Standard_B1s) | ~$0.30 | Auto-shutdown at 22:00 UTC saves ~30% |
| App Service (B1) | ~$0.44 | Fixed cost while plan exists |
| ACI (0.5 vCPU, 0.5 GB) | ~$0.30 | Per-second billing |
| ACR (Basic) | ~$0.17 | Fixed monthly ($5/mo) |
| Functions (Consumption) | ~$0.00 | Free grant covers lab usage |
| Batch Account | ~$0.00 | Account is free; pools cost extra |
| Storage (3 accounts) | ~$0.10 | Minimal usage |
| **Total** | **~$1.30–3.50** | Lower with auto-shutdown |

💡 **Cost tip:** Run `terraform destroy` when not studying. The entire module can be redeployed in ~5 minutes.
