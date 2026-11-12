# Module 11 — Networking

Demonstrates core Azure networking concepts: VNet peering, NSGs, route tables,
DNS, and optionally Azure Firewall, VPN Gateway, and Bastion. Networking
accounts for **30–35% of the AZ-305 exam** — this is the highest-weight domain.

## AZ-305 Exam Relevance

| Topic | Weight | What This Module Covers |
|---|---|---|
| VNet design & peering | **Critical** | Secondary VNet, bidirectional peering, non-transitive behaviour |
| Hub-and-spoke topology | **Critical** | Foundation = hub, secondary = spoke, UDR for transit |
| NSG & ASG | High | Layered security rules, priority ordering, logical grouping |
| Azure Firewall | High | Standard vs Premium, DNAT/Network/App rules (optional deploy) |
| VPN Gateway & ExpressRoute | High | S2S, P2S, VNet-to-VNet, ExpressRoute comparison (optional deploy) |
| Private Link vs Service Endpoints | High | Decision criteria, on-prem access, public IP elimination |
| Front Door vs App Gateway | High | Global vs regional L7 LB, CDN, WAF comparison |
| DNS (public & private zones) | Medium | Private DNS zone, VNet link, A record |
| Azure Bastion | Medium | Jump box replacement, SKU comparison (optional deploy) |
| UDR & forced tunneling | Medium | Custom routes, NVA next hop, BGP propagation |
| Network Watcher | Medium | Flow logs, connection troubleshoot, packet capture |
| DDoS Protection | Low | Infrastructure vs Network tier (reference only) |

## Networking Decision Tree

```
Need to connect two VNets?
├── Same Azure AD tenant, no encryption needed → VNet Peering
├── Different tenants or need encryption      → VNet-to-VNet VPN
└── Need transitive routing                   → Hub-spoke with NVA/Firewall

Need to connect on-premises to Azure?
├── Over internet, budget-friendly    → Site-to-Site VPN (up to ~10 Gbps)
├── Private, high-bandwidth, low-lat  → ExpressRoute (up to 100 Gbps)
└── Both (failover)                   → ExpressRoute + VPN backup

Need to secure traffic?
├── Per-subnet L3/L4 filtering (free) → NSG
├── Centralized L3–L7 + FQDN + TI    → Azure Firewall (Standard)
├── + TLS inspection + IDPS           → Azure Firewall (Premium)
└── DDoS beyond platform default      → DDoS Network Protection

Need to access PaaS privately?
├── From Azure VNet only, free        → Service Endpoint
├── From on-prem or need no public IP → Private Endpoint (Private Link)
└── Need cross-region access          → Private Endpoint

Need to load balance?
├── L4, regional, non-HTTP            → Azure Load Balancer
├── L7, regional, HTTP with WAF       → Application Gateway
├── L7, global, multi-region + CDN    → Azure Front Door
└── DNS-based, any protocol           → Traffic Manager

Need to manage VMs securely?
├── Browser-based RDP/SSH, no VM PIP  → Azure Bastion
└── Traditional jump box              → VM in management subnet (not recommended)
```

## Hub-and-Spoke Architecture

```
                    ┌──────────────────────┐
                    │    On-Premises        │
                    │    Data Centre        │
                    └──────────┬───────────┘
                               │ S2S VPN / ExpressRoute
                    ┌──────────▼───────────┐
                    │   Hub VNet (10.0/16)  │
                    │   ┌────────────────┐  │
                    │   │ VPN Gateway    │  │
                    │   │ Azure Firewall │  │
                    │   │ Bastion        │  │
                    │   │ Private DNS    │  │
                    │   └────────────────┘  │
                    └───┬──────────────┬────┘
                  Peering│            │Peering
              ┌─────────▼──┐    ┌────▼────────┐
              │ Spoke 1     │    │ Spoke 2      │
              │ (10.1/16)   │    │ (10.2/16)    │
              │ Workloads   │    │ Workloads    │
              └─────────────┘    └──────────────┘

    Spoke-to-spoke traffic routes through Hub Firewall (UDR)
    Peering is NON-TRANSITIVE — spokes cannot talk directly
```

## What This Module Creates

| Resource | Name Pattern | Purpose |
|---|---|---|
| Resource Group | `az305-lab-networking-rg-<suffix>` | Container for networking resources |
| Secondary VNet | `az305-lab-vnet-secondary-<suffix>` | Spoke VNet (10.1.0.0/16) with workload subnet |
| VNet Peering (×2) | `foundation-to-secondary` / `secondary-to-foundation` | Bidirectional peering |
| NSG | `az305-lab-nsg-web-<suffix>` | HTTP/HTTPS + SSH rules with explicit deny |
| ASG | `az305-lab-asg-web-<suffix>` | Logical NIC grouping for NSG rules |
| Route Table | `az305-lab-udr-<suffix>` | Custom route to NVA (UDR demo) |
| Public IP | `az305-lab-pip-networking-<suffix>` | Standard, static, zone-redundant |
| Private DNS Zone | `az305-lab-lab.example` | Internal DNS with VNet links |
| DNS A Record | `webapp.az305-lab-lab.example` | Sample record → 10.0.10.10 |
| Diagnostic Setting | `az305-lab-nsg-diag` | NSG logs → Log Analytics |

### Optional Expensive Resources

| Resource | Name Pattern | Daily Cost | Enable Variable |
|---|---|---|---|
| Azure Firewall + Policy | `az305-lab-fw-<suffix>` | **~$30/day** | `deploy_firewall = true` |
| VPN Gateway | `az305-lab-vpngw-<suffix>` | **~$3/day** | `deploy_vpn_gateway = true` |
| Azure Bastion | `az305-lab-bastion-<suffix>` | **~$5/day** | `deploy_bastion = true` |

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.5
- An Azure subscription with **Contributor** access
- Azure CLI authenticated: `az login`
- **Module 00 (Foundation)** deployed — provides VNet, subnets, Log Analytics

## Usage

```bash
# 1. Navigate to the module directory
cd az305-lab/modules/11-networking

# 2. Copy and customise variables
cp terraform.tfvars.example terraform.tfvars
# Fill in the foundation module outputs (vnet_id, vnet_name, subnet IDs, etc.)

# 3. Initialise Terraform
terraform init

# 4. Preview changes (base resources only — ~$0.50/day)
terraform plan

# 5. Deploy
terraform apply

# 6. Verify peering
az network vnet peering list \
  --resource-group $(terraform output -raw resource_group_name) \
  --vnet-name $(terraform output -raw secondary_vnet_name) \
  -o table

# 7. Verify DNS resolution (from a VM in the linked VNet)
# nslookup webapp.az305-lab-lab.example

# 8. (Optional) Deploy expensive resources one at a time
# Edit terraform.tfvars:  deploy_bastion = true
# terraform plan   # review the additional resources
# terraform apply

# 9. Clean up — destroy optional resources first if needed
terraform destroy
```

## Inputs

| Variable | Type | Default | Description |
|---|---|---|---|
| `location` | `string` | `"eastus"` | Azure region |
| `prefix` | `string` | `"az305-lab"` | Naming prefix for all resources |
| `foundation_resource_group_name` | `string` | — | Foundation resource group name |
| `foundation_vnet_id` | `string` | — | Foundation VNet resource ID |
| `foundation_vnet_name` | `string` | — | Foundation VNet name |
| `gateway_subnet_id` | `string` | — | GatewaySubnet resource ID |
| `bastion_subnet_id` | `string` | — | AzureBastionSubnet resource ID |
| `log_analytics_workspace_id` | `string` | — | Log Analytics workspace resource ID |
| `allowed_ssh_ip` | `string` | `"0.0.0.0/0"` | CIDR for SSH access (restrict in production) |
| `deploy_firewall` | `bool` | `false` | Deploy Azure Firewall (~$30/day) |
| `deploy_vpn_gateway` | `bool` | `false` | Deploy VPN Gateway (~$3/day) |
| `deploy_bastion` | `bool` | `false` | Deploy Azure Bastion (~$5/day) |
| `tags` | `map(string)` | Lab defaults | Tags merged onto every resource |

## Outputs

| Output | Description |
|---|---|
| `resource_group_name` | Name of the networking resource group |
| `secondary_vnet_id` | Resource ID of the secondary VNet |
| `secondary_vnet_name` | Name of the secondary VNet |
| `nsg_id` | Resource ID of the web NSG |
| `route_table_id` | Resource ID of the custom route table |
| `dns_zone_name` | Name of the private DNS zone |
| `public_ip_address` | Static public IP address |

## Dependencies

| Module | What It Provides |
|---|---|
| **00-foundation** | VNet, GatewaySubnet, AzureBastionSubnet, Log Analytics workspace |

## Estimated Cost

| Resource | Estimated Daily Cost |
|---|---|
| VNet, Peering, NSG, ASG, Route Table | Free |
| Public IP (Standard, static) | ~$0.12 |
| Private DNS Zone | ~$0.01 |
| Diagnostic settings | ~$0.30 (log ingestion) |
| **Base total** | **~$0.50/day** |
| + Azure Firewall (optional) | +$30/day |
| + VPN Gateway (optional) | +$3/day |
| + Azure Bastion (optional) | +$5/day |
| **Maximum total** | **~$38.50/day** |

> **Tip:** Leave `deploy_firewall`, `deploy_vpn_gateway`, and `deploy_bastion`
> set to `false` unless you are actively studying those topics. Run
> `terraform destroy` when not actively studying to stop all charges.

## Study Questions

1. VNet peering is non-transitive. If VNet A peers with VNet B, and VNet B
   peers with VNet C, can VNet A communicate with VNet C? How would you
   enable it?
2. When would you choose Azure Firewall over NSGs? When would you use both?
3. What is the difference between Service Endpoints and Private Endpoints?
   When would you choose each?
4. A customer needs to connect their on-premises data centre to Azure with
   guaranteed bandwidth and low latency. What do you recommend?
5. When would you choose Azure Front Door over Application Gateway?
6. What is forced tunneling and why do compliance frameworks require it?
7. Why must the gateway subnet be named exactly "GatewaySubnet"?
8. What are the three components of the Private Endpoint DNS pattern?
9. How does spoke-to-spoke communication work in a hub-and-spoke topology?
10. When would you recommend Azure Virtual WAN over a manual hub-spoke design?
