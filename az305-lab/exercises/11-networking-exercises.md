# Module 11: Networking — Exercises

## Exercise 1: Verify VNet Peering Is Established and Effective
**Difficulty:** 🟢 Guided
**Method:** CLI
**Estimated Time:** 10 minutes

### Objective
Verify that VNet peering is correctly configured and that resources in peered VNets can communicate.

### Instructions
1. List VNets in the resource group:
   ```bash
   az network vnet list \
     --resource-group rg-az305-lab \
     --output table \
     --query "[].{Name:name, AddressSpace:addressSpace.addressPrefixes[0], Location:location}"
   ```
2. List peering connections on each VNet:
   ```bash
   az network vnet peering list \
     --vnet-name <vnet-name> \
     --resource-group rg-az305-lab \
     --output table \
     --query "[].{Name:name, State:peeringState, RemoteVNet:remoteVirtualNetwork.id, AllowForwarded:allowForwardedTraffic, AllowGateway:allowGatewayTransit}"
   ```
3. Verify the peering state is "Connected" (both sides must show Connected):
   - If one side shows "Initiated" and the other "Disconnected," the peering is incomplete.
4. Test connectivity between VMs in the peered VNets:
   ```bash
   # From a VM in VNet A, ping a VM in VNet B
   ping <private-ip-of-vm-in-vnet-b>
   ```
5. Check effective routes on a NIC to verify the peering route:
   ```bash
   az network nic show-effective-route-table \
     --resource-group rg-az305-lab \
     --name <nic-name> \
     --output table
   ```

### Success Criteria
- Both sides of the peering show "Connected" state.
- VMs in peered VNets can communicate using private IPs.
- The effective route table shows routes to the peered VNet's address space.
- You understand peering properties: allowForwardedTraffic, allowGatewayTransit, useRemoteGateways.

### Explanation
VNet peering is a core AZ-305 networking topic. Key facts: peering is non-transitive (if A peers with B and B peers with C, A cannot reach C without a direct peering or a hub NVA/Azure Firewall). Peering can be within-region or global (cross-region). Gateway transit allows a peered VNet to use another VNet's VPN gateway. The exam tests hub-spoke designs where the hub VNet has the gateway and spokes peer with the hub.

---

## Exercise 2: List NSG Rules and Check Effective Security Rules on a NIC
**Difficulty:** 🟢 Guided
**Method:** CLI
**Estimated Time:** 10 minutes

### Objective
Inspect Network Security Group (NSG) rules and understand how effective security rules are computed from multiple NSGs.

### Instructions
1. List NSGs in the resource group:
   ```bash
   az network nsg list \
     --resource-group rg-az305-lab \
     --output table
   ```
2. View rules of a specific NSG:
   ```bash
   az network nsg rule list \
     --nsg-name <nsg-name> \
     --resource-group rg-az305-lab \
     --output table \
     --query "[].{Name:name, Priority:priority, Direction:direction, Access:access, Protocol:protocol, SourceAddr:sourceAddressPrefix, DestPort:destinationPortRange}"
   ```
3. Check the effective security rules on a specific NIC (combines subnet NSG + NIC NSG):
   ```bash
   az network nic list-effective-nsg \
     --resource-group rg-az305-lab \
     --name <nic-name> \
     --output json | jq '.value[0].effectiveSecurityRules[] | {name, direction, access, priority, sourceAddressPrefix, destinationPortRange}'
   ```
4. Identify which NSG is applied at the subnet level vs. the NIC level:
   ```bash
   az network vnet subnet show \
     --vnet-name <vnet-name> \
     --name <subnet-name> \
     --resource-group rg-az305-lab \
     --query "networkSecurityGroup.id" --output tsv
   ```

### Success Criteria
- You can list all rules in an NSG with their priorities.
- You can view the effective rules on a NIC (merged from subnet and NIC-level NSGs).
- You understand that rules are evaluated by priority (lowest number = highest priority).
- You know that NSGs can be applied at both subnet and NIC levels.

### Explanation
NSG rule evaluation is commonly tested on AZ-305. Rules are processed in priority order (100-4096). For inbound traffic: subnet NSG is evaluated first, then NIC NSG. For outbound: NIC NSG first, then subnet NSG. If either NSG denies the traffic, it is blocked. The exam tests scenarios where traffic is unexpectedly blocked and expects you to identify the conflicting rule. Best practice: apply NSGs at the subnet level for consistency, and at the NIC level only for exceptions.

---

## Exercise 3: Create a Custom NSG Rule and Test Connectivity
**Difficulty:** 🟡 Intermediate
**Method:** CLI
**Estimated Time:** 20 minutes

### Objective
Create a custom NSG rule to allow or deny specific traffic and verify the effect on connectivity.

### Instructions
1. Create a rule to allow HTTPS (port 443) from the internet:
   ```bash
   az network nsg rule create \
     --nsg-name <nsg-name> \
     --resource-group rg-az305-lab \
     --name AllowHTTPS \
     --priority 200 \
     --direction Inbound \
     --access Allow \
     --protocol Tcp \
     --source-address-prefixes Internet \
     --destination-port-ranges 443
   ```
2. Create a rule to deny all other inbound traffic from the internet:
   ```bash
   az network nsg rule create \
     --nsg-name <nsg-name> \
     --resource-group rg-az305-lab \
     --name DenyAllInbound \
     --priority 4000 \
     --direction Inbound \
     --access Deny \
     --protocol '*' \
     --source-address-prefixes Internet \
     --destination-port-ranges '*'
   ```
3. Test that HTTPS is allowed:
   ```bash
   curl -s -o /dev/null -w "%{http_code}" https://<vm-public-ip>:443
   ```
4. Test that HTTP (port 80) is denied:
   ```bash
   curl -s --connect-timeout 5 -o /dev/null -w "%{http_code}" http://<vm-public-ip>:80
   ```
5. Clean up the test rules when done.

### Success Criteria
- HTTPS traffic is allowed through the NSG.
- HTTP and other traffic is denied.
- You understand priority ordering (lower number rules are evaluated first).
- You can troubleshoot connectivity by examining NSG rules.

### Explanation
The exam tests NSG rule design for defense in depth. Key principle: default NSG rules allow all inbound from the VNet and load balancer, and deny all other inbound from the internet. Custom rules should be as specific as possible (use specific IPs, ports, and protocols). The exam also tests Application Security Groups (ASGs), which allow you to group NICs and write rules using group names instead of IP addresses, simplifying management in large environments.

---

## Exercise 4: Add a Route to the Route Table and Verify Routing
**Difficulty:** 🟡 Intermediate
**Method:** CLI
**Estimated Time:** 20 minutes

### Objective
Create a custom route in a User Defined Route (UDR) table and verify that traffic follows the custom route instead of the system default.

### Instructions
1. List route tables:
   ```bash
   az network route-table list \
     --resource-group rg-az305-lab \
     --output table
   ```
2. View existing routes:
   ```bash
   az network route-table route list \
     --route-table-name <route-table-name> \
     --resource-group rg-az305-lab \
     --output table
   ```
3. Add a custom route to send internet traffic through a network virtual appliance (NVA):
   ```bash
   az network route-table route create \
     --route-table-name <route-table-name> \
     --resource-group rg-az305-lab \
     --name ForceInternetToNVA \
     --address-prefix 0.0.0.0/0 \
     --next-hop-type VirtualAppliance \
     --next-hop-ip-address <nva-private-ip>
   ```
4. Associate the route table with a subnet:
   ```bash
   az network vnet subnet update \
     --vnet-name <vnet-name> \
     --name <subnet-name> \
     --resource-group rg-az305-lab \
     --route-table <route-table-name>
   ```
5. Verify effective routes on a NIC in that subnet:
   ```bash
   az network nic show-effective-route-table \
     --resource-group rg-az305-lab \
     --name <nic-name> \
     --output table
   ```
6. Test that internet traffic now flows through the NVA (traceroute or connectivity check).

### Success Criteria
- The custom route appears in the route table.
- Effective routes on the NIC show the UDR overriding system routes.
- Traffic to 0.0.0.0/0 is routed to the NVA instead of directly to the internet.
- You understand next-hop types: VirtualAppliance, VNetGateway, VNet, Internet, None.

### Explanation
UDRs are tested on AZ-305 for forced tunneling and hub-spoke designs. The exam tests scenarios where all internet-bound traffic must pass through a firewall (Azure Firewall or NVA). Key fact: UDRs override system routes (most specific prefix wins, and UDR takes precedence over system route for the same prefix). The 0.0.0.0/0 route to a VirtualAppliance is the classic forced tunneling pattern. The exam also tests that you must enable IP forwarding on the NVA's NIC.

---

## Exercise 5: Create a DNS Record in the Private DNS Zone
**Difficulty:** 🟡 Intermediate
**Method:** CLI
**Estimated Time:** 15 minutes

### Objective
Create a DNS record in an Azure Private DNS zone and verify name resolution from within the VNet.

### Instructions
1. List private DNS zones:
   ```bash
   az network private-dns zone list \
     --resource-group rg-az305-lab \
     --output table
   ```
2. List existing records in a zone:
   ```bash
   az network private-dns record-set list \
     --zone-name <zone-name> \
     --resource-group rg-az305-lab \
     --output table
   ```
3. Create an A record:
   ```bash
   az network private-dns record-set a add-record \
     --zone-name <zone-name> \
     --resource-group rg-az305-lab \
     --record-set-name myapp \
     --ipv4-address 10.0.1.10
   ```
4. Verify the record exists:
   ```bash
   az network private-dns record-set a show \
     --zone-name <zone-name> \
     --resource-group rg-az305-lab \
     --name myapp \
     --output json | jq '{fqdn, aRecords}'
   ```
5. Check VNet links (the DNS zone must be linked to the VNet for resolution):
   ```bash
   az network private-dns link vnet list \
     --zone-name <zone-name> \
     --resource-group rg-az305-lab \
     --output table
   ```
6. From a VM in the linked VNet, resolve the name:
   ```bash
   nslookup myapp.<zone-name>
   ```

### Success Criteria
- The A record is created in the private DNS zone.
- The DNS zone is linked to the VNet.
- Name resolution works from VMs in the linked VNet.
- You understand that private DNS zones are not resolvable from outside the linked VNets.

### Explanation
Private DNS zones are critical for private endpoints and internal name resolution. AZ-305 tests: private DNS zones for private endpoint resolution (e.g., privatelink.blob.core.windows.net), auto-registration of VM names in private DNS zones, and the relationship between VNet links and DNS resolution scope. The exam also tests Azure DNS Private Resolver for hybrid DNS scenarios (on-premises resolving Azure private DNS and vice versa).

---

## Exercise 6: Design a Hub-Spoke Network for an Enterprise
**Difficulty:** 🔴 Challenge
**Method:** Conceptual
**Estimated Time:** 30 minutes

### Objective
Design a hub-spoke network topology for an enterprise with 5 workloads, centralized security, and on-premises connectivity.

### Instructions
Design the network addressing:

1. **Address space planning:**
   - Hub VNet: central services (firewall, VPN gateway, DNS).
   - 5 spoke VNets: one per workload (web, API, database, management, dev/test).
   - Non-overlapping IP ranges (plan for future growth).
   - Subnet design within each VNet.

2. **Hub services:**
   - Azure Firewall vs. third-party NVA: selection criteria?
   - VPN Gateway or ExpressRoute for on-premises connectivity?
   - Azure Bastion for secure VM management.
   - Private DNS zones in the hub.

3. **Spoke connectivity:**
   - VNet peering from each spoke to hub.
   - Peering properties: allowForwardedTraffic, useRemoteGateways.
   - UDRs in spokes to force traffic through the hub firewall.
   - How do spokes communicate with each other? (Through the hub firewall)

4. **Security:**
   - Azure Firewall rules: network rules, application rules, DNAT rules.
   - NSGs on each subnet for defense in depth.
   - DDoS Protection plan on the hub VNet.
   - Network flow logs for auditing.

5. **DNS:**
   - Private DNS zones for internal name resolution.
   - DNS forwarding for hybrid resolution (Azure to on-premises and vice versa).
   - Azure DNS Private Resolver in the hub.

6. **Scalability:**
   - What happens when you need more than 5 workloads?
   - Azure Virtual WAN as an alternative to manual hub-spoke.
   - When to transition from hub-spoke to Virtual WAN.

### Success Criteria
- IP address ranges are non-overlapping and allow for growth.
- Azure Firewall in the hub inspects all inter-spoke and internet traffic.
- VPN Gateway or ExpressRoute provides on-premises connectivity.
- UDRs in spokes route traffic through the hub.
- DNS resolution works for both Azure and on-premises names.

### Explanation
Hub-spoke is the most common AZ-305 networking design. The exam tests: Azure Firewall as the central security appliance (supports FQDN filtering, threat intelligence, TLS inspection), VNet peering properties for gateway transit, UDRs for forced tunneling through the hub. Key exam insight: spokes cannot communicate with each other through peering alone (peering is non-transitive). Traffic between spokes must flow through the hub firewall, which provides inspection and policy enforcement. Azure Virtual WAN simplifies this for large-scale deployments.

---

## Exercise 7: Design Private Connectivity from On-Premises
**Difficulty:** 🔴 Challenge
**Method:** Conceptual
**Estimated Time:** 30 minutes

### Objective
**Scenario:** An organization needs private connectivity from their on-premises datacenter to Azure with less than 10ms latency and 10 Gbps bandwidth. They have 200 VMs in Azure across 3 regions. Security policy requires all traffic to be encrypted. The organization also needs to connect to Microsoft 365 services.

Design the connectivity solution.

### Instructions
Evaluate and design:

1. **Connectivity technology:**
   - VPN Gateway: max bandwidth per tunnel? (1.25 Gbps for S2S VPN)
   - ExpressRoute: available bandwidths? (50 Mbps to 10 Gbps)
   - ExpressRoute Direct: 10 Gbps or 100 Gbps port pairs.
   - Can VPN meet the 10 Gbps and 10ms requirements? (No, VPN has higher latency and lower bandwidth)

2. **ExpressRoute design:**
   - Peering types: Azure Private (Azure VNets), Microsoft (M365, Dynamics).
   - Azure Private peering for VM connectivity.
   - Microsoft peering for Microsoft 365 (requires approval).
   - ExpressRoute Global Reach for connecting on-premises sites through Microsoft backbone.

3. **Redundancy and HA:**
   - Two ExpressRoute circuits (different peering locations) for redundancy?
   - ExpressRoute + VPN Gateway as backup (coexisting connections)?
   - Zone-redundant gateway for within-region resilience.
   - What happens if one circuit fails?

4. **Encryption:**
   - ExpressRoute traffic is private but not encrypted by default.
   - MACsec for ExpressRoute Direct (Layer 2 encryption).
   - IPsec VPN over ExpressRoute private peering (Layer 3 encryption).
   - Which option for the "all traffic must be encrypted" requirement?

5. **Multi-region connectivity:**
   - ExpressRoute with Global Reach to connect regions.
   - Or ExpressRoute circuit with connections to multiple VNets.
   - Gateway transit and VNet peering across regions.

6. **Cost considerations:**
   - ExpressRoute circuit cost (monthly fee + data transfer).
   - Unlimited vs. metered data plans.
   - Premium add-on for global connectivity (cross-region).

### Success Criteria
- ExpressRoute (not VPN) is selected for the bandwidth and latency requirements.
- Azure Private peering connects to VNets, Microsoft peering connects to M365.
- Redundancy uses dual circuits at different peering locations.
- Encryption uses MACsec (ExpressRoute Direct) or IPsec VPN over ExpressRoute.
- The design supports all 3 Azure regions via ExpressRoute Premium or Virtual WAN.

### Explanation
ExpressRoute design is a high-value AZ-305 topic. The exam tests: when to use ExpressRoute vs. VPN (bandwidth > 1 Gbps, latency-sensitive, or compliance requirements). ExpressRoute provides private connectivity but not encryption by default, which is a common exam trap. For encryption, use MACsec (ExpressRoute Direct only, Layer 2) or run IPsec VPN tunnels over the ExpressRoute private peering (any ExpressRoute, Layer 3). The Premium add-on is needed for cross-region connectivity and access to more than 4,000 routes from on-premises.
