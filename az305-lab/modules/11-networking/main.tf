# =============================================================================
# AZ-305 Lab — Module 11: Networking
# =============================================================================
# Demonstrates core Azure networking services: VNet peering, NSGs, ASGs,
# route tables, DNS, and optionally Azure Firewall, VPN Gateway, and Bastion.
#
# AZ-305 Exam Relevance:
#   - Design network solutions accounts for 30–35% of the exam
#   - VNet design: address spaces, subnets, peering, hub-spoke topology
#   - Network security: NSGs, ASGs, Azure Firewall, DDoS Protection
#   - Connectivity: VPN Gateway, ExpressRoute, peering, Private Link
#   - Load balancing: Front Door vs App Gateway vs Load Balancer vs Traffic Mgr
#   - DNS: public zones, private zones, zone delegation, Private DNS
#   - Monitoring: Network Watcher, flow logs, connection troubleshoot
#
# Cost: ~$0.50/day base. Optional resources add significantly:
#   - Azure Firewall: ~$30/day (Standard SKU)
#   - VPN Gateway:    ~$3/day  (VpnGw1 SKU)
#   - Azure Bastion:  ~$5/day  (Basic SKU)
# =============================================================================

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "azurerm" {
  features {}
}

# -----------------------------------------------------------------------------
# Local values
# -----------------------------------------------------------------------------
locals {
  common_tags = merge(var.tags, {
    Module  = "11-networking"
    Purpose = "Networking services and connectivity"
  })

  suffix = random_string.suffix.result
}

# -----------------------------------------------------------------------------
# Random suffix — globally unique resource names
# -----------------------------------------------------------------------------
resource "random_string" "suffix" {
  length  = 6
  upper   = false
  special = false
}

# =============================================================================
# Resource Group
# =============================================================================
resource "azurerm_resource_group" "networking" {
  name     = "${var.prefix}-mod11-networking-rg-${local.suffix}"
  location = var.location
  tags     = local.common_tags

  lifecycle {
    # Non-semantic: Azure auto-adds rg-class tag for internal classification. Not a config choice.
    ignore_changes = [tags["rg-class"]]
  }
}

# =============================================================================
# Secondary Virtual Network — multi-VNet architecture demo
# =============================================================================
# AZ-305 EXAM TOPIC: VNet Design
# ---------------------------------------------------------------------------
# Real-world Azure environments almost always use multiple VNets:
#   - Separation of concerns (prod vs dev, app tiers, teams)
#   - Blast radius isolation (security boundary per VNet)
#   - Address space management (each VNet has its own CIDR)
#   - Regional distribution (VNets are regional resources)
#
# Key design decisions:
#   - Address spaces MUST NOT overlap if you plan to peer VNets
#   - Subnets carve up the VNet address space; plan for growth
#   - Some Azure services require dedicated subnets (delegation)
#     e.g., AzureBastionSubnet, GatewaySubnet, App Service VNet Integration
#   - /16 per VNet is common; /24 per subnet gives 251 usable IPs
#     (Azure reserves 5 addresses per subnet)
# ---------------------------------------------------------------------------
resource "azurerm_virtual_network" "secondary" {
  name                = "${var.prefix}-vnet-secondary-${local.suffix}"
  location            = azurerm_resource_group.networking.location
  resource_group_name = azurerm_resource_group.networking.name
  address_space       = ["10.1.0.0/16"]
  tags                = local.common_tags
}

resource "azurerm_subnet" "workload" {
  name                 = "workload"
  resource_group_name  = azurerm_resource_group.networking.name
  virtual_network_name = azurerm_virtual_network.secondary.name
  address_prefixes     = ["10.1.0.0/24"]
}

# =============================================================================
# VNet Peering — bidirectional connectivity between VNets
# =============================================================================
# AZ-305 EXAM TOPIC: VNet Peering (CRITICAL — appears on almost every exam)
# ---------------------------------------------------------------------------
# VNet peering connects two VNets over the Azure backbone (no public internet).
#
# CRITICAL EXAM FACTS:
#   1. Peering is NON-TRANSITIVE: if A↔B and B↔C, A cannot reach C unless
#      you also peer A↔C or route through an NVA/firewall in B.
#   2. Peering must be configured in BOTH directions (two peering resources).
#   3. Address spaces MUST NOT overlap.
#   4. Peering can be same-region or cross-region (global peering).
#   5. Global peering has higher latency and bandwidth limits.
#
# Gateway Transit:
#   - A hub VNet with a VPN Gateway can share it with peered spokes.
#   - Hub side: allow_gateway_transit = true
#   - Spoke side: use_remote_gateways = true
#   - This avoids deploying a VPN Gateway in every spoke VNet.
#
# Forwarded Traffic:
#   - allow_forwarded_traffic = true lets traffic forwarded by an NVA
#     (e.g., Azure Firewall) traverse the peering.
#   - Required for hub-and-spoke with centralized firewall routing.
# ---------------------------------------------------------------------------

# Foundation VNet → Secondary VNet
resource "azurerm_virtual_network_peering" "foundation_to_secondary" {
  name                         = "foundation-to-secondary"
  resource_group_name          = var.foundation_resource_group_name
  virtual_network_name         = var.foundation_vnet_name
  remote_virtual_network_id    = azurerm_virtual_network.secondary.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = false
}

# Secondary VNet → Foundation VNet
resource "azurerm_virtual_network_peering" "secondary_to_foundation" {
  name                         = "secondary-to-foundation"
  resource_group_name          = azurerm_resource_group.networking.name
  virtual_network_name         = azurerm_virtual_network.secondary.name
  remote_virtual_network_id    = var.foundation_vnet_id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  use_remote_gateways          = false
}

# =============================================================================
# AZ-305 EXAM TOPIC: Hub-and-Spoke Topology (exam favorite)
# =============================================================================
# Hub-and-spoke is THE networking architecture pattern for Azure:
#
#   Hub VNet (shared services):
#     - Azure Firewall or NVA for centralized traffic inspection
#     - VPN Gateway / ExpressRoute Gateway for on-premises connectivity
#     - Azure Bastion for secure management access
#     - Shared DNS (private DNS zones linked here)
#     - In this lab: Foundation VNet = Hub
#
#   Spoke VNets (workloads):
#     - Peered to hub; isolated from each other by default
#     - Use UDRs to force spoke-to-spoke traffic through hub firewall
#     - Each spoke can represent a team, environment, or application
#     - In this lab: Secondary VNet = Spoke
#
#   Spoke-to-Spoke Communication:
#     - Peering is non-transitive → spokes can't talk directly
#     - Option 1: UDR in each spoke → hub firewall → other spoke
#     - Option 2: Azure Virtual WAN (managed hub-spoke)
#     - Option 3: Direct peering between spokes (doesn't scale)
#
#   Azure Virtual WAN:
#     - Microsoft-managed hub with built-in routing and transit
#     - Supports VPN, ExpressRoute, and SD-WAN integration
#     - Scales better than manual hub-spoke for large environments
#     - Exam tip: recommend Virtual WAN for 30+ branches or complex routing
# =============================================================================

# =============================================================================
# Network Security Group — layered security rules
# =============================================================================
# AZ-305 EXAM TOPIC: NSG vs Azure Firewall
# ---------------------------------------------------------------------------
# NSG (Network Security Group):
#   - Layer 3/4 stateful packet filter
#   - Applied per-subnet or per-NIC
#   - Rules: priority + direction + protocol + port + source/destination
#   - Free (no additional cost)
#   - Best for: micro-segmentation, subnet-level access control
#   - Limitations: no FQDN filtering, no TLS inspection, no threat intel
#
# Azure Firewall:
#   - Layer 3–7 managed firewall service
#   - Centralized in hub VNet, inspects all traffic
#   - Features: FQDN filtering, threat intelligence, TLS inspection (Premium),
#     IDPS (Premium), URL filtering, web categories
#   - Cost: ~$30/day (Standard), ~$45/day (Premium)
#   - Best for: centralized egress control, compliance requirements
#
# When to use which (exam decision):
#   - NSG: always (baseline security for every subnet)
#   - Firewall: when you need FQDN-based rules, threat intelligence,
#     centralized logging, or compliance mandates L7 inspection
#   - Both together: defence in depth (NSG at subnet + Firewall at hub)
# ---------------------------------------------------------------------------
resource "azurerm_network_security_group" "web" {
  name                = "${var.prefix}-nsg-web-${local.suffix}"
  location            = azurerm_resource_group.networking.location
  resource_group_name = azurerm_resource_group.networking.name
  tags                = local.common_tags

  # --- Inbound Rules ---
  # Rules are evaluated by PRIORITY (lowest number = highest priority).
  # First matching rule wins; remaining rules are not evaluated.

  # Allow HTTP from the internet (web traffic)
  security_rule {
    name                       = "AllowHTTP"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }

  # Allow HTTPS from the internet (secure web traffic)
  security_rule {
    name                       = "AllowHTTPS"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }

  # Allow SSH from a specific IP (management access)
  # In production: restrict to a jump box or Bastion subnet, never "any"
  security_rule {
    name                       = "AllowSSH"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = var.allowed_ssh_ip
    destination_address_prefix = "*"
  }

  # Deny all other inbound traffic — explicit catch-all
  # Azure has implicit deny rules at priority 65500, but explicit deny
  # at a lower priority makes the intent clear in logs and audits.
  security_rule {
    name                       = "DenyAllInbound"
    priority                   = 4000
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# =============================================================================
# Application Security Group — logical grouping for NSG rules
# =============================================================================
# AZ-305 EXAM TOPIC: Application Security Groups
# ---------------------------------------------------------------------------
# ASGs let you group NICs by application role instead of IP addresses.
# Benefits:
#   - NSG rules reference ASGs instead of IP ranges
#   - VMs can be added/removed from ASGs without changing NSG rules
#   - Makes rules self-documenting: "Allow web-servers → db-servers on 1433"
#   - Reduces rule count in complex environments
#
# Example pattern:
#   - ASG "web-servers": all web tier NICs
#   - ASG "db-servers": all database tier NICs
#   - NSG rule: Allow TCP/1433 from web-servers to db-servers
#
# Exam tip: ASGs work within a single VNet. Cross-VNet ASG rules are not
# supported — use IP ranges or service tags for cross-VNet rules.
# ---------------------------------------------------------------------------
resource "azurerm_application_security_group" "web" {
  name                = "${var.prefix}-asg-web-${local.suffix}"
  location            = azurerm_resource_group.networking.location
  resource_group_name = azurerm_resource_group.networking.name
  tags                = local.common_tags
}

# =============================================================================
# Route Table — User Defined Routes (UDR)
# =============================================================================
# AZ-305 EXAM TOPIC: User Defined Routes and Forced Tunneling
# ---------------------------------------------------------------------------
# Azure has system routes that automatically handle VNet, peered VNet, and
# internet traffic. UDRs OVERRIDE these system routes.
#
# Common use cases:
#   1. Forced tunneling: route all internet-bound traffic through a firewall
#      (0.0.0.0/0 → NVA or Azure Firewall private IP)
#   2. Spoke-to-spoke routing: force inter-spoke traffic through hub firewall
#   3. On-premises routing: direct traffic to on-prem via VPN/ExpressRoute
#
# Next hop types:
#   - VirtualNetworkGateway: VPN/ExpressRoute gateway
#   - VnetLocal: within the VNet (system default)
#   - Internet: Azure's default internet path
#   - VirtualAppliance: NVA/firewall IP address
#   - None: drop the traffic (black hole)
#
# Forced Tunneling:
#   - Route 0.0.0.0/0 → VirtualAppliance (firewall) or VirtualNetworkGateway
#   - All internet traffic exits through your inspection point
#   - Required by many compliance frameworks
#   - Exam: know that this breaks Azure PaaS services that need outbound
#     internet — use service endpoints or Private Link as workaround
# ---------------------------------------------------------------------------
resource "azurerm_route_table" "custom" {
  name                = "${var.prefix}-udr-${local.suffix}"
  location            = azurerm_resource_group.networking.location
  resource_group_name = azurerm_resource_group.networking.name
  tags                = local.common_tags

  # Disable BGP route propagation to prevent VPN/ExpressRoute routes
  # from overriding our custom routes. Useful when you want strict
  # control over routing in specific subnets.
  bgp_route_propagation_enabled = false

  # Example: route traffic destined for 10.2.0.0/16 through an NVA
  # In a real environment, this would be the Azure Firewall private IP
  # or a third-party NVA. This demonstrates the concept with a placeholder.
  route {
    name                   = "to-remote-network"
    address_prefix         = "10.2.0.0/16"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = "10.0.10.4"
  }
}

# =============================================================================
# Public IP — standard SKU for future use
# =============================================================================
# Standard SKU public IPs are zone-redundant by default and required by
# modern Azure services (Standard LB, Azure Firewall, Application Gateway v2).
# Basic SKU is being retired — always use Standard for new deployments.
resource "azurerm_public_ip" "networking" {
  name                = "${var.prefix}-pip-networking-${local.suffix}"
  location            = azurerm_resource_group.networking.location
  resource_group_name = azurerm_resource_group.networking.name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = ["1", "2", "3"]
  tags                = local.common_tags
}

# =============================================================================
# Private DNS Zone — Azure DNS for internal name resolution
# =============================================================================
# AZ-305 EXAM TOPIC: Azure DNS — Public vs Private Zones
# ---------------------------------------------------------------------------
# Public DNS Zones:
#   - Hosted on Azure's global anycast DNS network
#   - Resolves names from the internet (e.g., app.contoso.com)
#   - Supports zone delegation from registrars
#   - Alias records can point to Azure resources (LB, Traffic Manager, CDN)
#
# Private DNS Zones:
#   - Resolves names ONLY within linked VNets
#   - No internet visibility — internal service discovery
#   - Auto-registration: VMs automatically get DNS records when linked
#   - Critical for Private Endpoints (e.g., privatelink.blob.core.windows.net)
#
# Zone Delegation (exam topic):
#   - Parent zone delegates a subdomain to child zone's name servers
#   - Allows teams to manage their own DNS subdomains independently
#   - Works the same way in Azure as traditional DNS delegation
# ---------------------------------------------------------------------------
resource "azurerm_private_dns_zone" "lab" {
  name                = "az305-lab.example"
  resource_group_name = azurerm_resource_group.networking.name
  tags                = local.common_tags
}

# Link the private DNS zone to the foundation VNet so VMs can resolve records
resource "azurerm_private_dns_zone_virtual_network_link" "lab" {
  name                  = "${var.prefix}-dns-link-foundation"
  resource_group_name   = azurerm_resource_group.networking.name
  private_dns_zone_name = azurerm_private_dns_zone.lab.name
  virtual_network_id    = var.foundation_vnet_id
  registration_enabled  = false
  tags                  = local.common_tags
}

# Link to secondary VNet as well for cross-VNet resolution
resource "azurerm_private_dns_zone_virtual_network_link" "lab_secondary" {
  name                  = "${var.prefix}-dns-link-secondary"
  resource_group_name   = azurerm_resource_group.networking.name
  private_dns_zone_name = azurerm_private_dns_zone.lab.name
  virtual_network_id    = azurerm_virtual_network.secondary.id
  registration_enabled  = false
  tags                  = local.common_tags
}

# Sample A record — demonstrates manual DNS record creation
resource "azurerm_private_dns_a_record" "sample" {
  name                = "webapp"
  zone_name           = azurerm_private_dns_zone.lab.name
  resource_group_name = azurerm_resource_group.networking.name
  ttl                 = 300
  records             = ["10.0.10.10"]
  tags                = local.common_tags
}

# =============================================================================
# NSG Diagnostic Settings — send logs to Log Analytics
# =============================================================================
# NSG flow logs and diagnostic settings are essential for:
#   - Security auditing (who accessed what)
#   - Troubleshooting connectivity issues
#   - Compliance reporting
#   - Traffic analytics (requires Log Analytics workspace)
resource "azurerm_monitor_diagnostic_setting" "nsg" {
  name                       = "${var.prefix}-nsg-diag"
  target_resource_id         = azurerm_network_security_group.web.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "NetworkSecurityGroupEvent"
  }

  enabled_log {
    category = "NetworkSecurityGroupRuleCounter"
  }
}

# =============================================================================
# AZ-305 EXAM TOPIC: Network Watcher (reference)
# =============================================================================
# Network Watcher provides:
#   - Connection Troubleshoot: test connectivity between Azure resources
#   - Packet Capture: capture traffic on a VM NIC for analysis
#   - NSG Flow Logs: log all traffic evaluated by NSG rules
#   - IP Flow Verify: check if a specific packet would be allowed/denied
#   - Next Hop: determine the next hop for a given destination
#   - VPN Troubleshoot: diagnose VPN Gateway connectivity issues
#   - Traffic Analytics: visualize flow log data in Log Analytics
#
# Network Watcher is auto-created per region when you create VNet resources.
# NSG Flow Logs require a storage account — in production, use a dedicated
# storage account with lifecycle policies to manage retention and costs.
# =============================================================================

# =============================================================================
# Azure Firewall (OPTIONAL — ~$30/day)
# =============================================================================
# AZ-305 EXAM TOPIC: Azure Firewall Tiers
# ---------------------------------------------------------------------------
# Standard SKU:
#   - L3–L7 filtering with threat intelligence
#   - FQDN-based application rules (e.g., allow *.microsoft.com)
#   - Network rules (IP/port/protocol)
#   - DNAT rules (inbound traffic forwarding)
#   - Threat intelligence: alert/deny known malicious IPs and FQDNs
#
# Premium SKU (adds to Standard):
#   - TLS inspection (decrypt, inspect, re-encrypt HTTPS traffic)
#   - IDPS (Intrusion Detection and Prevention System)
#   - URL filtering (beyond FQDN — full URL path matching)
#   - Web categories (block social media, gambling, etc.)
#
# Rule Processing Order:
#   1. DNAT rules (inbound NAT)
#   2. Network rules (L3/L4)
#   3. Application rules (L7 FQDN)
#   If no rule matches: traffic is denied by default
#
# Azure Firewall Manager:
#   - Central management of multiple firewalls across VNets and regions
#   - Firewall policies with inheritance (parent → child)
#   - Integration with Virtual WAN secured hubs
# ---------------------------------------------------------------------------

resource "azurerm_firewall_policy" "main" {
  count               = var.deploy_firewall ? 1 : 0
  name                = "${var.prefix}-fw-policy-${local.suffix}"
  resource_group_name = azurerm_resource_group.networking.name
  location            = azurerm_resource_group.networking.location
  sku                 = "Standard"
  tags                = local.common_tags
}

resource "azurerm_public_ip" "firewall" {
  count               = var.deploy_firewall ? 1 : 0
  name                = "${var.prefix}-pip-fw-${local.suffix}"
  location            = azurerm_resource_group.networking.location
  resource_group_name = azurerm_resource_group.networking.name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = ["1", "2", "3"]
  tags                = local.common_tags
}

# Azure Firewall requires a dedicated subnet named "AzureFirewallSubnet"
# with at least /26. We create it in the secondary VNet for this demo.
resource "azurerm_subnet" "firewall" {
  count                = var.deploy_firewall ? 1 : 0
  name                 = "AzureFirewallSubnet"
  resource_group_name  = azurerm_resource_group.networking.name
  virtual_network_name = azurerm_virtual_network.secondary.name
  address_prefixes     = ["10.1.1.0/26"]
}

resource "azurerm_firewall" "main" {
  count               = var.deploy_firewall ? 1 : 0
  name                = "${var.prefix}-fw-${local.suffix}"
  location            = azurerm_resource_group.networking.location
  resource_group_name = azurerm_resource_group.networking.name
  sku_name            = "AZFW_VNet"
  sku_tier            = "Standard"
  firewall_policy_id  = azurerm_firewall_policy.main[0].id
  tags                = local.common_tags

  ip_configuration {
    name                 = "fw-ipconfig"
    subnet_id            = azurerm_subnet.firewall[0].id
    public_ip_address_id = azurerm_public_ip.firewall[0].id
  }
}

# =============================================================================
# VPN Gateway (OPTIONAL — ~$3/day)
# =============================================================================
# AZ-305 EXAM TOPIC: VPN Gateway and Connectivity Options
# ---------------------------------------------------------------------------
# VPN Gateway Types:
#   - Site-to-Site (S2S): connects on-premises network to Azure VNet
#     via IPsec/IKE tunnel over the internet. Requires on-prem VPN device.
#   - Point-to-Site (P2S): connects individual client machines to Azure VNet.
#     Protocols: OpenVPN, SSTP, IKEv2. Supports Azure AD authentication.
#   - VNet-to-VNet: IPsec tunnel between two Azure VNets.
#     Alternative to peering; useful when you need encryption in transit
#     or need to connect VNets in different Azure AD tenants.
#
# Gateway SKUs (know for exam):
#   - VpnGw1: 650 Mbps, 250 S2S tunnels, 250 P2S connections
#   - VpnGw2: 1 Gbps
#   - VpnGw3: 1.25 Gbps
#   - VpnGw1AZ–VpnGw3AZ: zone-redundant versions
#   - Higher SKUs: more tunnels, throughput, and BGP support
#
# VPN vs ExpressRoute (CRITICAL exam comparison):
#   - VPN: over public internet, encrypted (IPsec), up to ~10 Gbps
#   - ExpressRoute: private connection via connectivity provider,
#     does NOT traverse the internet, up to 100 Gbps, lower latency
#   - ExpressRoute + VPN: use VPN as failover for ExpressRoute
#   - ExpressRoute Global Reach: connect on-prem sites through Azure backbone
#
# Gateway Subnet:
#   - MUST be named "GatewaySubnet" (Azure requirement)
#   - Recommended /27 or larger (need IPs for gateway instances)
#   - Do NOT associate an NSG with GatewaySubnet (breaks gateway)
#   - Do NOT associate a route table that blocks gateway traffic
# ---------------------------------------------------------------------------

resource "azurerm_public_ip" "vpn_gateway" {
  count               = var.deploy_vpn_gateway ? 1 : 0
  name                = "${var.prefix}-pip-vpngw-${local.suffix}"
  location            = azurerm_resource_group.networking.location
  resource_group_name = azurerm_resource_group.networking.name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = ["1", "2", "3"]
  tags                = local.common_tags
}

resource "azurerm_virtual_network_gateway" "main" {
  count               = var.deploy_vpn_gateway ? 1 : 0
  name                = "${var.prefix}-vpngw-${local.suffix}"
  location            = azurerm_resource_group.networking.location
  resource_group_name = var.foundation_resource_group_name
  type                = "Vpn"
  vpn_type            = "RouteBased"
  sku                 = "VpnGw1"
  generation          = "Generation1"
  tags                = local.common_tags

  ip_configuration {
    name                          = "vpngw-ipconfig"
    public_ip_address_id          = azurerm_public_ip.vpn_gateway[0].id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = var.gateway_subnet_id
  }
}

# =============================================================================
# Azure Bastion (OPTIONAL — ~$5/day)
# =============================================================================
# AZ-305 EXAM TOPIC: Azure Bastion
# ---------------------------------------------------------------------------
# Bastion provides secure RDP/SSH connectivity to VMs WITHOUT public IPs.
#
# How it works:
#   - Deployed into AzureBastionSubnet in your VNet
#   - You connect via the Azure portal (browser-based RDP/SSH)
#   - Traffic: Your browser → Bastion (TLS) → VM (private IP, RDP/SSH)
#   - VMs never need public IPs or NSG rules for management access
#
# SKUs:
#   - Basic: browser-based RDP/SSH, manual IP selection
#   - Standard: adds native client support, IP-based connections,
#     shareable links, upload/download, Kerberos auth
#   - Premium: adds session recording, private-only deployment
#
# Bastion Subnet Requirements:
#   - MUST be named "AzureBastionSubnet" (Azure requirement)
#   - Minimum /26 (64 addresses)
#   - NSG rules: allow inbound HTTPS (443) from Internet,
#     allow outbound to VirtualNetwork (RDP/SSH ports)
#
# Exam tip: Bastion replaces jump boxes / bastion hosts. It eliminates the
# need to manage and patch a dedicated VM just for management access.
# ---------------------------------------------------------------------------

resource "azurerm_public_ip" "bastion" {
  count               = var.deploy_bastion ? 1 : 0
  name                = "${var.prefix}-pip-bastion-${local.suffix}"
  location            = azurerm_resource_group.networking.location
  resource_group_name = azurerm_resource_group.networking.name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = ["1", "2", "3"]
  tags                = local.common_tags
}

resource "azurerm_bastion_host" "main" {
  count               = var.deploy_bastion ? 1 : 0
  name                = "${var.prefix}-bastion-${local.suffix}"
  location            = azurerm_resource_group.networking.location
  resource_group_name = var.foundation_resource_group_name
  sku                 = "Basic"
  tags                = local.common_tags

  ip_configuration {
    name                 = "bastion-ipconfig"
    subnet_id            = var.bastion_subnet_id
    public_ip_address_id = azurerm_public_ip.bastion[0].id
  }
}

# =============================================================================
# AZ-305 EXAM TOPIC: Front Door vs Application Gateway
# =============================================================================
# Application Gateway:
#   - Regional Layer 7 load balancer
#   - WAF (Web Application Firewall) with OWASP rules
#   - SSL termination, cookie-based session affinity
#   - URL-based routing (e.g., /images → pool A, /api → pool B)
#   - Autoscaling (v2 SKU)
#   - Private front-end IP (internal LB) or public
#   - Best for: regional web applications needing L7 features
#
# Azure Front Door:
#   - Global Layer 7 load balancer + CDN + WAF
#   - Anycast routing (users hit nearest POP automatically)
#   - SSL offloading, URL-based routing, session affinity
#   - Built-in CDN with caching at edge
#   - Global WAF policies
#   - Private Link to backend (Premium SKU)
#   - Best for: global applications, multi-region failover, CDN needs
#
# Decision:
#   - Single region → Application Gateway
#   - Multi-region + global users → Front Door
#   - Need CDN + LB → Front Door (combines both)
#   - Internal-only (private IP front-end) → Application Gateway
# =============================================================================

# =============================================================================
# AZ-305 EXAM TOPIC: Private Link vs Service Endpoints
# =============================================================================
# Service Endpoints:
#   - Optimizes routing: traffic goes over Azure backbone instead of internet
#   - The PaaS resource STILL has a public IP
#   - Configuration: enable on subnet + add VNet rule on the PaaS resource
#   - Free; no additional resources needed
#   - Limitation: works only from the configured VNet/subnet
#   - Limitation: cannot be used from on-premises (traffic still has to
#     reach Azure's public endpoint)
#
# Private Link / Private Endpoint:
#   - Creates a NIC with a PRIVATE IP in your VNet
#   - The PaaS resource is accessed via the private IP — no public IP needed
#   - Works from on-premises (via VPN/ExpressRoute to the VNet)
#   - Requires Private DNS zone for name resolution
#   - Cost: ~$0.24/day per endpoint + data processing charges
#   - Best for: compliance (no public exposure), on-premises connectivity
#
# Decision (exam favorite):
#   - Need access from on-prem? → Private Endpoint (service endpoints don't
#     work from on-prem)
#   - Need to eliminate public IP entirely? → Private Endpoint
#   - Just need optimized routing from Azure VNet? → Service Endpoint (free)
#   - Need cross-region access? → Private Endpoint (service endpoints are
#     limited to the same region as the VNet)
# =============================================================================

# =============================================================================
# AZ-305 EXAM TOPIC: Azure DDoS Protection (reference only — expensive)
# =============================================================================
# DDoS Protection tiers:
#   - Infrastructure (default): automatically protects all Azure resources,
#     no configuration needed, free with Azure platform.
#   - Network (formerly Standard): ~$2,944/month fixed + overages.
#     Adds: adaptive tuning, attack analytics, cost protection guarantee,
#     rapid response team, integration with Firewall Manager.
#   - IP: per-IP protection at lower cost than Network tier.
#
# Exam tip: Infrastructure protection is always on. Only enable Network
# tier if you have public-facing workloads requiring SLA guarantees,
# attack telemetry, or cost protection from DDoS-induced scaling.
# =============================================================================
