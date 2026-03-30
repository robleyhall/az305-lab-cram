# AZ-305 Lab — Architecture Documentation

> **Lab Purpose:** Hands-on Terraform lab for the AZ-305 (Designing Microsoft Azure Infrastructure Solutions) certification exam. 13 modules deploy real Azure resources mapped to each exam domain.

---

## Table of Contents

1. [Overall Architecture Diagram](#1-overall-architecture-diagram)
2. [Per-Module Architecture Diagrams](#2-per-module-architecture-diagrams)
3. [Resource Inventory Table](#3-resource-inventory-table)
4. [Dependency Map](#4-dependency-map)
5. [Network Topology Diagram](#5-network-topology-diagram)
6. [Exam Domain Mapping](#6-exam-domain-mapping)

---

## 1. Overall Architecture Diagram

```mermaid
flowchart TB
    subgraph AZ305["AZ-305 Lab Environment"]
        subgraph M00["Module 00 — Foundation"]
            RG0[Resource Group]
            VNET["VNet 10.0.0.0/16"]
            LAW[Log Analytics Workspace]
            NSG0[Default NSG]
        end

        subgraph M01["Module 01 — Governance"]
            MGMT[Management Group]
            POLICY1[Policy: Require CostCenter Tag]
            POLICY2[Policy: Restrict VM SKUs]
            POLICY3[Policy: Allowed Locations]
            POLICY4[Initiative: Security Benchmark]
            RBAC1[Custom Role: Lab Reader Plus]
            LOCK1[Resource Lock: CanNotDelete]
        end

        subgraph M02["Module 02 — Identity"]
            GROUPS["Entra ID Groups<br/>Admins / Developers / Readers"]
            APPREG[App Registration]
            SP[Service Principal]
            UMID2[User-Assigned Managed Identity]
            ROLEASSIGN["Role Assignments<br/>Reader / Contributor"]
        end

        subgraph M03["Module 03 — Key Vault"]
            KV[Key Vault]
            SECRET[Secret: db-connection-string]
            KEY[Key: RSA 2048 Encryption]
            CERT[Certificate: TLS Demo]
            UMID3[Managed Identity]
            PE_KV[Private Endpoint]
            PDNS_KV[Private DNS Zone]
        end

        subgraph M04["Module 04 — Monitoring"]
            APPINS[Application Insights]
            AG[Action Group: Email Alerts]
            CPUALERT[Metric Alert: CPU > 80%]
            LOGALERT[Log Alert: Error Events]
            ACTALERT[Activity Log Alert: Deletes]
            DASH[Portal Dashboard]
        end

        subgraph M05["Module 05 — HA/DR"]
            AVSET["Availability Set<br/>FD=2, UD=5"]
            VM1[VM 1 — AvSet]
            VM2[VM 2 — AvSet]
            VM3[VM 3 — Zone 1]
            PLB[Public Load Balancer]
            ILB[Internal Load Balancer]
            RSV[Recovery Services Vault]
            BACKUP[Backup Policy: Daily]
            TM[Traffic Manager: Performance]
        end

        subgraph M06["Module 06 — Storage"]
            SA1[Storage Account: GPv2]
            SA2[Storage Account: Premium Blob]
            SA3[Storage Account: Data Lake Gen2]
            BLOB[Blob Containers]
            FSHARE[File Share]
            LIFECYCLE[Lifecycle Rules]
            MDISK[Managed Disks]
            PE_SA[Private Endpoint]
        end

        subgraph M07["Module 07 — Databases"]
            SQLSRV[SQL Server]
            SQLDB1[SQL DB: Basic DTU]
            SQLDB2[SQL DB: Serverless vCore]
            EPOOL[Elastic Pool]
            COSMOS[CosmosDB: Serverless]
            PE_SQL[Private Endpoint]
        end

        subgraph M08["Module 08 — Data Integration"]
            ADF[Data Factory]
            ADFLS[Linked Service]
            ADFPIPE[Pipeline]
            DLAKE[Data Lake Gen2: Medallion]
            EG08[Event Grid Topic]
        end

        subgraph M09["Module 09 — Compute"]
            LINVM[Linux VM]
            ASP[App Service Plan]
            WEBAPP[Web App]
            ACI[Container Instance]
            ACR[Container Registry]
            FUNC[Function App]
            BATCH[Batch Account]
        end

        subgraph M10["Module 10 — App Architecture"]
            EGTOPIC[Event Grid Topic]
            EGSUB[Event Grid Subscription]
            EHNS[Event Hubs Namespace]
            EH[Event Hub]
            SBNS[Service Bus Namespace]
            SBQ[Service Bus Queue]
            SBT[Service Bus Topic]
            APIM[API Management: Consumption]
            REDIS[Redis Cache: Basic]
        end

        subgraph M11["Module 11 — Networking"]
            VNET2["Secondary VNet 10.1.0.0/16"]
            PEER["VNet Peering"]
            NSG11[NSG]
            ASG11[App Security Group]
            RT[Route Table]
            PDNS11[Private DNS Zone]
        end

        subgraph M12["Module 12 — Migration"]
            MIGRATE[Azure Migrate Project]
            RSV12[Recovery Services Vault]
            DMS[Database Migration Service]
            STAGESA[Staging Storage Account]
            SIMVM[Simulated On-Prem VM]
        end
    end

    %% Foundation connections
    VNET --> M03
    VNET --> M05
    VNET --> M06
    VNET --> M07
    VNET --> M09
    VNET --> M11
    VNET --> M12
    LAW --> M01
    LAW --> M02
    LAW --> M03
    LAW --> M04
    LAW --> M05
    LAW --> M10

    %% Key relationships
    PE_KV -.->|privatelink| KV
    PLB -->|HTTP:80| VM1
    PLB -->|HTTP:80| VM2
    RSV -->|backup| VM1
    RSV -->|backup| VM2
    TM -->|endpoint| PLB
    PEER --- VNET
    PEER --- VNET2
```

---

## 2. Per-Module Architecture Diagrams

### Module 00 — Foundation

```mermaid
flowchart TB
    subgraph RG["Resource Group: foundation"]
        VNET["Virtual Network<br/>10.0.0.0/16"]
        LAW["Log Analytics Workspace<br/>SKU: PerGB2018 · 30-day retention"]
        NSG["Network Security Group"]
        SUFFIX["random_string: suffix (6 chars)"]

        subgraph Subnets
            S0["default<br/>10.0.0.0/24"]
            S1["governance<br/>10.0.1.0/24"]
            S2["identity<br/>10.0.2.0/24"]
            S3["keyvault<br/>10.0.3.0/24"]
            S4["monitoring<br/>10.0.4.0/24"]
            S5["compute<br/>10.0.5.0/24"]
            S6["storage<br/>10.0.6.0/24"]
            S7["database<br/>10.0.7.0/24"]
            S8["data-integration<br/>10.0.8.0/24"]
            S9["app-architecture<br/>10.0.9.0/24"]
            S10["networking<br/>10.0.10.0/24"]
            S11["migration<br/>10.0.11.0/24"]
            S250["AzureBastionSubnet<br/>10.0.250.0/24"]
            S251["GatewaySubnet<br/>10.0.251.0/24"]
        end
    end

    VNET --> Subnets
    NSG -->|associated| S0

    style LAW fill:#4a9,stroke:#333,color:#fff
    style VNET fill:#47a,stroke:#333,color:#fff
```

### Module 01 — Governance & Compliance

```mermaid
flowchart TB
    subgraph RG["Resource Group: governance"]
        subgraph Policies["Policy Definitions & Assignments"]
            PD1["Policy: Require CostCenter Tag<br/>Effect: deny"]
            PD2["Policy: Restrict VM SKUs<br/>Effect: deny · B1s,B1ms,B2s,B2ms,D2s_v5,D2as_v5"]
            PA1["Assignment: Allowed Locations<br/>Built-in · eastus only"]
            PA2["Assignment: Security Benchmark<br/>Built-in initiative · audit mode"]
        end

        ROLE["Custom Role: Lab Reader Plus<br/>*/read + VM restart/start/deallocate + metrics"]
        LOCK["Resource Lock: CanNotDelete"]
        MGMT["Management Group<br/>(conditional · disabled by default)"]
    end

    PD1 -->|assigned to| RG
    PD2 -->|assigned to| RG
    PA1 -->|assigned to| RG
    LOCK -->|protects| RG
```

### Module 02 — Identity & Access

```mermaid
flowchart TB
    subgraph RG["Resource Group: identity"]
        UMID["User-Assigned Managed Identity"]
    end

    subgraph EntraID["Entra ID"]
        G1["Group: Admins"]
        G2["Group: Developers"]
        G3["Group: Readers"]
        APP["App Registration<br/>AzureADMyOrg"]
        SP["Service Principal"]
    end

    subgraph RBAC["Role Assignments"]
        RA1["Readers → Reader"]
        RA2["Developers → Contributor"]
    end

    subgraph Optional["Optional (Entra ID P1+)"]
        CAP["Conditional Access Policy<br/>Require MFA for Admins · Report-only"]
    end

    APP --> SP
    G3 --> RA1
    G2 --> RA2
    RA1 -->|scope| RG
    RA2 -->|scope| RG
    G1 -.-> CAP

    DIAG["Diagnostic Setting<br/>SignInLogs + AuditLogs → LAW"]
    EntraID --> DIAG
```

### Module 03 — Key Vault & Application Identity

```mermaid
flowchart TB
    subgraph RG["Resource Group: keyvault"]
        KV["Key Vault<br/>SKU: standard · RBAC auth<br/>Soft delete: 7 days"]
        UMID["Managed Identity"]

        subgraph Secrets["Vault Contents"]
            SECRET["Secret: db-connection-string"]
            KEY["Key: RSA 2048<br/>az305-lab-encryption-key"]
            CERT["Certificate: Self-signed TLS<br/>CN=az305-lab-demo.azure.local<br/>12-month validity"]
        end

        subgraph PrivateAccess["Private Networking"]
            PE["Private Endpoint"]
            PDNS["Private DNS Zone<br/>privatelink.vaultcore.azure.net"]
            LINK["VNet Link"]
        end
    end

    subgraph RoleAssignments["RBAC"]
        RA1["Current User → KV Administrator"]
        RA2["Managed Identity → KV Secrets User"]
        RA3["Managed Identity → KV Crypto User"]
    end

    KV --> Secrets
    PE -->|privatelink| KV
    PDNS --> LINK
    LINK -->|linked to| VNET["Foundation VNet"]
    UMID --> RA2
    UMID --> RA3
    DIAG["Diagnostic Setting<br/>AuditEvent + AllMetrics → LAW"] --> KV
```

### Module 04 — Monitoring & Alerting

```mermaid
flowchart TB
    subgraph RG["Resource Group: monitoring"]
        APPINS["Application Insights<br/>Type: web · Workspace-based"]
        AG["Action Group<br/>Email receiver"]

        subgraph Alerts
            MA["Metric Alert<br/>CPU > 80% avg 5 min<br/>Severity: 2"]
            ALA["Activity Log Alert<br/>Resource deletions"]
            LQA["Scheduled Query Alert<br/>KQL: Error events<br/>Severity: 2"]
        end

        DASH["Portal Dashboard<br/>4 markdown tiles"]
        DIAG["Subscription Diagnostic Setting<br/>Admin + Security + Policy logs"]
    end

    MA -->|fires| AG
    ALA -->|fires| AG
    LQA -->|fires| AG
    APPINS -->|sends to| LAW["Log Analytics Workspace"]
    DIAG -->|routes to| LAW

    style APPINS fill:#e74,stroke:#333,color:#fff
```

### Module 05 — High Availability & Disaster Recovery

```mermaid
flowchart TB
    subgraph RG["Resource Group: ha-dr"]
        subgraph AvailabilitySet["Availability Set · FD=2 UD=5"]
            VM1["Linux VM 1<br/>B1s · Ubuntu 22.04"]
            VM2["Linux VM 2<br/>B1s · Ubuntu 22.04"]
        end
        VM3["Linux VM 3<br/>B1s · Ubuntu 22.04<br/>Zone 1"]

        subgraph LoadBalancing["Load Balancing"]
            PIP["Public IP: Static · Standard"]
            PLB["Public Load Balancer<br/>Standard SKU"]
            PROBE["Health Probe<br/>TCP:80 · 5s interval"]
            RULE["LB Rule: HTTP:80→80"]
            ILB["Internal Load Balancer<br/>Standard SKU · Private IP"]
        end

        subgraph DR["Disaster Recovery"]
            RSV["Recovery Services Vault<br/>Standard · GeoRedundant"]
            BPOL["Backup Policy<br/>Daily 02:00 UTC · 7-day retention"]
            TM["Traffic Manager<br/>Routing: Performance<br/>DNS TTL: 60s"]
        end

        SSH["TLS Private Key: RSA 4096"]
        SHUT["Auto-Shutdown: 22:00 UTC"]
    end

    PLB --> VM1
    PLB --> VM2
    PIP --> PLB
    PROBE --> PLB
    RSV --> BPOL
    BPOL -->|protects| VM1
    BPOL -->|protects| VM2
    TM -->|endpoint| PIP
    SHUT -.->|scheduled| VM1
    SHUT -.->|scheduled| VM2
    SHUT -.->|scheduled| VM3
```

### Module 06 — Storage Solutions

```mermaid
flowchart TB
    subgraph RG["Resource Group: storage"]
        SA1["Storage Account: GPv2<br/>Standard LRS"]
        SA2["Storage Account: Premium<br/>Premium Blob"]
        SA3["Storage Account: Data Lake Gen2<br/>HNS enabled"]

        subgraph Objects["Storage Objects"]
            BLOB["Blob Containers"]
            FSHARE["File Share"]
        end

        LIFECYCLE["Lifecycle Management Rules<br/>Cool → Archive tiering"]
        MDISK["Managed Disks"]

        subgraph PrivateAccess["Private Networking"]
            PE["Private Endpoint"]
        end
    end

    SA1 --> BLOB
    SA1 --> FSHARE
    SA1 --> LIFECYCLE
    PE -->|privatelink| SA1
    SA3 -->|ADLS Gen2| BLOB
```

### Module 07 — Databases

```mermaid
flowchart TB
    subgraph RG["Resource Group: databases"]
        SQLSRV["Azure SQL Server"]
        subgraph SQLDatabases["SQL Databases"]
            DB1["SQL DB: Basic DTU<br/>DTU-based pricing"]
            DB2["SQL DB: Serverless vCore<br/>Auto-pause enabled"]
        end
        EPOOL["Elastic Pool"]

        COSMOS["CosmosDB Account<br/>Serverless capacity mode"]

        subgraph PrivateAccess["Private Networking"]
            PE["Private Endpoint"]
        end
    end

    SQLSRV --> DB1
    SQLSRV --> DB2
    SQLSRV --> EPOOL
    PE -->|privatelink| SQLSRV
```

### Module 08 — Data Integration

```mermaid
flowchart TB
    subgraph RG["Resource Group: data-integration"]
        ADF["Azure Data Factory"]
        LS["Linked Service"]
        PIPE["Pipeline"]

        DLAKE["Data Lake Gen2"]
        subgraph Medallion["Medallion Architecture"]
            BRONZE["Container: bronze"]
            SILVER["Container: silver"]
            GOLD["Container: gold"]
        end

        EG["Event Grid Topic"]
    end

    ADF --> LS
    ADF --> PIPE
    PIPE -->|reads/writes| DLAKE
    DLAKE --> Medallion
    EG -->|triggers| PIPE
```

### Module 09 — Compute

```mermaid
flowchart TB
    subgraph RG["Resource Group: compute"]
        VM["Linux VM"]

        subgraph AppService["App Service"]
            ASP["App Service Plan"]
            WEBAPP["Web App"]
        end

        ACI["Container Instance"]
        ACR["Container Registry"]
        FUNC["Function App"]
        BATCH["Batch Account"]
    end

    ASP --> WEBAPP
    ACR -->|image source| ACI
    ACR -->|image source| FUNC
```

### Module 10 — Application Architecture

```mermaid
flowchart TB
    subgraph RG["Resource Group: app-architecture"]
        subgraph EventGrid["Event Grid"]
            EGTOPIC["Event Grid Topic<br/>Schema: EventGridSchema"]
            EGSUB["Event Subscription<br/>Webhook: example.com/api/events"]
        end

        subgraph EventHubs["Event Hubs"]
            EHNS["Namespace: Standard · 1 TU"]
            EH["Event Hub<br/>2 partitions · 1-day retention"]
            CG["Consumer Group"]
        end

        subgraph ServiceBus["Service Bus"]
            SBNS["Namespace: Standard"]
            SBQ["Queue<br/>1024 MB · Dead-letter enabled"]
            SBT["Topic<br/>1024 MB"]
            SBSUB["Subscription<br/>Max delivery: 10"]
        end

        APIM["API Management<br/>Consumption tier"]
        REDIS["Redis Cache<br/>Basic · C0 · TLS 1.2"]

        DIAG1["Diagnostic: Event Hubs → LAW"]
        DIAG2["Diagnostic: Service Bus → LAW"]
        DIAG3["Diagnostic: APIM → LAW"]
    end

    EGTOPIC --> EGSUB
    EHNS --> EH
    EH --> CG
    SBNS --> SBQ
    SBNS --> SBT
    SBT --> SBSUB

    style APIM fill:#c5a,stroke:#333,color:#fff
    style REDIS fill:#a44,stroke:#333,color:#fff
```

### Module 11 — Networking (Advanced)

```mermaid
flowchart TB
    subgraph RG["Resource Group: networking"]
        VNET2["Secondary VNet<br/>10.1.0.0/16"]
        PEER["VNet Peering<br/>Bidirectional"]
        NSG["Network Security Group"]
        ASG["Application Security Group"]
        RT["Route Table<br/>Custom routes"]
        PDNS["Private DNS Zone"]

        subgraph Optional["Optional (Higher Cost)"]
            FW["Azure Firewall"]
            VPNGW["VPN Gateway"]
            BASTION["Azure Bastion"]
        end
    end

    VNET1["Foundation VNet<br/>10.0.0.0/16"] <-->|peering| PEER
    PEER <--> VNET2
    NSG -->|rules| ASG
    RT -->|associated| VNET2
```

### Module 12 — Migration

```mermaid
flowchart TB
    subgraph RG["Resource Group: migration"]
        MIGRATE["Azure Migrate Project<br/>Assessment + Discovery"]
        RSV["Recovery Services Vault<br/>ASR replication"]
        DMS["Database Migration Service"]
        STAGESA["Staging Storage Account<br/>Replication cache"]
        SIMVM["Simulated On-Prem VM<br/>Migration source"]
    end

    SIMVM -->|discovered by| MIGRATE
    SIMVM -->|replicates to| RSV
    DMS -->|migrates schema & data| SQLDB["Target SQL DB (Module 07)"]
    STAGESA -->|cache for| RSV
```

---

## 3. Resource Inventory Table

### Module 00 — Foundation

| Resource | Azure Resource Type | Purpose | Est. Monthly Cost |
|----------|-------------------|---------|-------------------|
| Resource Group | `azurerm_resource_group` | Container for foundation resources | Free |
| Virtual Network | `azurerm_virtual_network` | Primary VNet 10.0.0.0/16 | Free |
| Subnet: default | `azurerm_subnet` | General-purpose 10.0.0.0/24 | Free |
| Subnet: governance | `azurerm_subnet` | Governance module 10.0.1.0/24 | Free |
| Subnet: identity | `azurerm_subnet` | Identity module 10.0.2.0/24 | Free |
| Subnet: keyvault | `azurerm_subnet` | Key Vault module 10.0.3.0/24 | Free |
| Subnet: monitoring | `azurerm_subnet` | Monitoring module 10.0.4.0/24 | Free |
| Subnet: compute | `azurerm_subnet` | Compute module 10.0.5.0/24 | Free |
| Subnet: storage | `azurerm_subnet` | Storage module 10.0.6.0/24 | Free |
| Subnet: database | `azurerm_subnet` | Database module 10.0.7.0/24 | Free |
| Subnet: data-integration | `azurerm_subnet` | Data integration module 10.0.8.0/24 | Free |
| Subnet: app-architecture | `azurerm_subnet` | App architecture module 10.0.9.0/24 | Free |
| Subnet: networking | `azurerm_subnet` | Networking module 10.0.10.0/24 | Free |
| Subnet: migration | `azurerm_subnet` | Migration module 10.0.11.0/24 | Free |
| Subnet: AzureBastionSubnet | `azurerm_subnet` | Azure Bastion 10.0.250.0/24 | Free |
| Subnet: GatewaySubnet | `azurerm_subnet` | VPN/ER Gateway 10.0.251.0/24 | Free |
| Network Security Group | `azurerm_network_security_group` | Default NSG with 3 rules | Free |
| NSG Association | `azurerm_subnet_network_security_group_association` | NSG → default subnet | Free |
| Log Analytics Workspace | `azurerm_log_analytics_workspace` | Central logging (PerGB2018, 30-day) | ~$2–5 |
| Random Suffix | `random_string` | 6-char unique naming suffix | Free |

### Module 01 — Governance

| Resource | Azure Resource Type | Purpose | Est. Monthly Cost |
|----------|-------------------|---------|-------------------|
| Resource Group | `azurerm_resource_group` | Governance resources container | Free |
| Policy: Require CostCenter Tag | `azurerm_policy_definition` | Custom deny policy for tagging | Free |
| Policy: Restrict VM SKUs | `azurerm_policy_definition` | Custom deny policy limiting VM sizes | Free |
| Assignment: CostCenter Tag | `azurerm_resource_group_policy_assignment` | Enforce tag requirement | Free |
| Assignment: Allowed Locations | `azurerm_resource_group_policy_assignment` | Built-in policy — eastus only | Free |
| Assignment: Security Benchmark | `azurerm_resource_group_policy_assignment` | Built-in initiative — audit mode | Free |
| Custom Role: Lab Reader Plus | `azurerm_role_definition` | Read + VM ops + metrics | Free |
| Management Group | `azurerm_management_group` | Lab management group (conditional) | Free |
| Resource Lock | `azurerm_management_lock` | CanNotDelete on governance RG | Free |

### Module 02 — Identity

| Resource | Azure Resource Type | Purpose | Est. Monthly Cost |
|----------|-------------------|---------|-------------------|
| Resource Group | `azurerm_resource_group` | Identity resources container | Free |
| Entra ID Group: Admins | `azuread_group` | Security group for administrators | Free |
| Entra ID Group: Developers | `azuread_group` | Security group for developers | Free |
| Entra ID Group: Readers | `azuread_group` | Security group for read-only users | Free |
| App Registration | `azuread_application` | Lab application in Entra ID | Free |
| Service Principal | `azuread_service_principal` | Service identity for app registration | Free |
| Role Assignment: Readers | `azurerm_role_assignment` | Reader role on identity RG | Free |
| Role Assignment: Developers | `azurerm_role_assignment` | Contributor role on identity RG | Free |
| Conditional Access Policy | `azuread_conditional_access_policy` | MFA for admins (report-only, P1+ required) | Free* |
| Diagnostic Setting | `azurerm_monitor_aad_diagnostic_setting` | SignInLogs + AuditLogs → LAW | Free** |
| User-Assigned Managed Identity | `azurerm_user_assigned_identity` | Shared managed identity for modules | Free |

### Module 03 — Key Vault

| Resource | Azure Resource Type | Purpose | Est. Monthly Cost |
|----------|-------------------|---------|-------------------|
| Resource Group | `azurerm_resource_group` | Key Vault resources container | Free |
| Key Vault | `azurerm_key_vault` | Secrets/keys/certs management (standard SKU) | ~$0.03/op |
| Managed Identity | `azurerm_user_assigned_identity` | Identity for KV RBAC access | Free |
| Role: KV Administrator | `azurerm_role_assignment` | Current user admin access | Free |
| Role: KV Secrets User | `azurerm_role_assignment` | Managed identity secret read | Free |
| Role: KV Crypto User | `azurerm_role_assignment` | Managed identity key operations | Free |
| Secret: db-connection-string | `azurerm_key_vault_secret` | Demo database connection string | ~$0.03/10K ops |
| Key: RSA 2048 Encryption | `azurerm_key_vault_key` | Encryption key (software-protected) | ~$0.03/10K ops |
| Certificate: TLS Demo | `azurerm_key_vault_certificate` | Self-signed cert (12-month validity) | ~$3 |
| Private DNS Zone | `azurerm_private_dns_zone` | privatelink.vaultcore.azure.net | ~$0.50 |
| VNet Link | `azurerm_private_dns_zone_virtual_network_link` | DNS zone → VNet association | Free |
| Private Endpoint | `azurerm_private_endpoint` | Private access to Key Vault | ~$7.30 |
| Diagnostic Setting | `azurerm_monitor_diagnostic_setting` | AuditEvent + AllMetrics → LAW | Free** |

### Module 04 — Monitoring

| Resource | Azure Resource Type | Purpose | Est. Monthly Cost |
|----------|-------------------|---------|-------------------|
| Resource Group | `azurerm_resource_group` | Monitoring resources container | Free |
| Application Insights | `azurerm_application_insights` | APM (workspace-based, web type) | ~$2–5 |
| Action Group | `azurerm_monitor_action_group` | Email notification receiver | Free |
| Metric Alert: CPU | `azurerm_monitor_metric_alert` | CPU > 80% on VMs (severity 2) | ~$0.10 |
| Activity Log Alert | `azurerm_monitor_activity_log_alert` | Resource deletion detection | Free |
| Scheduled Query Alert | `azurerm_monitor_scheduled_query_rules_alert_v2` | KQL error event query (severity 2) | ~$1.50 |
| Subscription Diagnostic Setting | `azurerm_monitor_diagnostic_setting` | Activity log routing → LAW | Free** |
| Portal Dashboard | `azurerm_portal_dashboard` | Monitoring overview (4 tiles) | Free |

### Module 05 — HA/DR

| Resource | Azure Resource Type | Purpose | Est. Monthly Cost |
|----------|-------------------|---------|-------------------|
| Resource Group | `azurerm_resource_group` | HA/DR resources container | Free |
| SSH Key | `tls_private_key` | RSA 4096 key for VM access | Free |
| Availability Set | `azurerm_availability_set` | FD=2 UD=5 for VM placement | Free |
| NIC × 2 (AvSet) | `azurerm_network_interface` | NICs for availability set VMs | Free |
| NIC (Zone) | `azurerm_network_interface` | NIC for zone VM | Free |
| Linux VM × 2 (AvSet) | `azurerm_linux_virtual_machine` | B1s Ubuntu 22.04 in avail. set | ~$7.60 × 2 |
| Linux VM (Zone 1) | `azurerm_linux_virtual_machine` | B1s Ubuntu 22.04 in zone 1 | ~$7.60 |
| Auto-Shutdown × 3 | `azurerm_dev_test_global_vm_shutdown_schedule` | 22:00 UTC cost control | Free |
| Public IP | `azurerm_public_ip` | Static Standard IP for public LB | ~$3.65 |
| Public Load Balancer | `azurerm_lb` | Standard external LB | ~$18.25 |
| LB Backend Pool | `azurerm_lb_backend_address_pool` | Backend pool for avset VMs | Free |
| LB NIC Association × 2 | `azurerm_network_interface_backend_address_pool_association` | VMs → backend pool | Free |
| LB Health Probe | `azurerm_lb_probe` | TCP:80 health check (5s interval) | Free |
| LB Rule: HTTP | `azurerm_lb_rule` | Port 80 → 80 with TCP reset | Free |
| Internal Load Balancer | `azurerm_lb` | Standard internal LB (private IP) | ~$18.25 |
| Internal LB Backend Pool | `azurerm_lb_backend_address_pool` | Backend pool for internal LB | Free |
| Recovery Services Vault | `azurerm_recovery_services_vault` | Standard SKU, GeoRedundant | ~$10 |
| VM Backup Policy | `azurerm_backup_policy_vm` | Daily 02:00 UTC, 7-day retention | Included |
| Backup Protected VM × 2 | `azurerm_backup_protected_vm` | AvSet VMs registered for backup | ~$5 × 2 |
| Traffic Manager Profile | `azurerm_traffic_manager_profile` | Performance routing, 60s TTL | ~$0.75 |
| Traffic Manager Endpoint | `azurerm_traffic_manager_azure_endpoint` | Points to public LB IP | Included |

### Module 06 — Storage

| Resource | Azure Resource Type | Purpose | Est. Monthly Cost |
|----------|-------------------|---------|-------------------|
| Resource Group | `azurerm_resource_group` | Storage resources container | Free |
| Storage Account: GPv2 | `azurerm_storage_account` | General-purpose Standard LRS | ~$1–3 |
| Storage Account: Premium | `azurerm_storage_account` | Premium Blob performance tier | ~$2–5 |
| Storage Account: Data Lake | `azurerm_storage_account` | ADLS Gen2 (HNS enabled) | ~$1–3 |
| Blob Containers | `azurerm_storage_container` | Object storage containers | Free |
| File Share | `azurerm_storage_share` | SMB file share | ~$1 |
| Lifecycle Rules | `azurerm_storage_management_policy` | Cool → Archive tiering automation | Free |
| Managed Disks | `azurerm_managed_disk` | Standalone disk resources | ~$1–5 |
| Private Endpoint | `azurerm_private_endpoint` | Private access to storage | ~$7.30 |

### Module 07 — Databases

| Resource | Azure Resource Type | Purpose | Est. Monthly Cost |
|----------|-------------------|---------|-------------------|
| Resource Group | `azurerm_resource_group` | Database resources container | Free |
| Azure SQL Server | `azurerm_mssql_server` | Logical SQL server | Free |
| SQL DB: Basic DTU | `azurerm_mssql_database` | DTU-based pricing (Basic tier, 5 DTUs) | ~$4.90 |
| SQL DB: Serverless vCore | `azurerm_mssql_database` | Serverless with auto-pause | ~$5–15 |
| Elastic Pool | `azurerm_mssql_elasticpool` | Shared DTU/vCore pool | ~$15–30 |
| CosmosDB Account | `azurerm_cosmosdb_account` | Serverless NoSQL database | ~$0–5 |
| Private Endpoint | `azurerm_private_endpoint` | Private access to SQL Server | ~$7.30 |

### Module 08 — Data Integration

| Resource | Azure Resource Type | Purpose | Est. Monthly Cost |
|----------|-------------------|---------|-------------------|
| Resource Group | `azurerm_resource_group` | Data integration resources container | Free |
| Data Factory | `azurerm_data_factory` | ETL/ELT orchestration | ~$0–5 |
| Linked Service | `azurerm_data_factory_linked_service_*` | Connection to data stores | Free |
| Pipeline | `azurerm_data_factory_pipeline` | Data movement pipeline | Free |
| Data Lake Gen2 | `azurerm_storage_account` | Medallion architecture store (HNS) | ~$1–3 |
| Containers: bronze/silver/gold | `azurerm_storage_container` | Medallion layer containers | Free |
| Event Grid Topic | `azurerm_eventgrid_topic` | Event-driven pipeline triggers | ~$0.60 |

### Module 09 — Compute

| Resource | Azure Resource Type | Purpose | Est. Monthly Cost |
|----------|-------------------|---------|-------------------|
| Resource Group | `azurerm_resource_group` | Compute resources container | Free |
| Linux VM | `azurerm_linux_virtual_machine` | IaaS compute demo | ~$7.60 |
| App Service Plan | `azurerm_service_plan` | Hosting plan for web app | ~$13–55 |
| Web App | `azurerm_linux_web_app` | PaaS web application | Included |
| Container Instance | `azurerm_container_group` | Serverless container | ~$1–3 |
| Container Registry | `azurerm_container_registry` | Private image registry | ~$5 |
| Function App | `azurerm_linux_function_app` | Serverless compute | ~$0–2 |
| Batch Account | `azurerm_batch_account` | Batch processing | ~$0–1 |

### Module 10 — App Architecture

| Resource | Azure Resource Type | Purpose | Est. Monthly Cost |
|----------|-------------------|---------|-------------------|
| Resource Group | `azurerm_resource_group` | App architecture resources container | Free |
| Event Grid Topic | `azurerm_eventgrid_topic` | Custom event publishing | ~$0.60 |
| Event Grid Subscription | `azurerm_eventgrid_event_subscription` | Webhook event delivery | Free |
| Event Hubs Namespace | `azurerm_eventhub_namespace` | Standard tier, 1 TU | ~$11 |
| Event Hub | `azurerm_eventhub` | 2 partitions, 1-day retention | Included |
| Consumer Group | `azurerm_eventhub_consumer_group` | Parallel event processing | Free |
| Service Bus Namespace | `azurerm_servicebus_namespace` | Standard tier messaging | ~$10 |
| Service Bus Queue | `azurerm_servicebus_queue` | 1024 MB, dead-letter enabled | Included |
| Service Bus Topic | `azurerm_servicebus_topic` | 1024 MB pub/sub topic | Included |
| Service Bus Subscription | `azurerm_servicebus_subscription` | Topic subscriber (max delivery: 10) | Included |
| API Management | `azurerm_api_management` | Consumption tier API gateway | ~$3.50 |
| Redis Cache | `azurerm_redis_cache` | Basic C0, TLS 1.2 | ~$16 |
| Diagnostic: Event Hubs | `azurerm_monitor_diagnostic_setting` | ArchiveLogs + OperationalLogs → LAW | Free** |
| Diagnostic: Service Bus | `azurerm_monitor_diagnostic_setting` | OperationalLogs → LAW | Free** |
| Diagnostic: APIM | `azurerm_monitor_diagnostic_setting` | GatewayLogs → LAW | Free** |

### Module 11 — Networking

| Resource | Azure Resource Type | Purpose | Est. Monthly Cost |
|----------|-------------------|---------|-------------------|
| Resource Group | `azurerm_resource_group` | Networking resources container | Free |
| Secondary VNet | `azurerm_virtual_network` | Second VNet 10.1.0.0/16 | Free |
| VNet Peering (primary → secondary) | `azurerm_virtual_network_peering` | Bidirectional peering | ~$0 (data transfer) |
| VNet Peering (secondary → primary) | `azurerm_virtual_network_peering` | Bidirectional peering | ~$0 (data transfer) |
| NSG | `azurerm_network_security_group` | Secondary VNet security rules | Free |
| Application Security Group | `azurerm_application_security_group` | Logical grouping for NSG rules | Free |
| Route Table | `azurerm_route_table` | Custom routing rules | Free |
| Private DNS Zone | `azurerm_private_dns_zone` | Internal name resolution | ~$0.50 |
| Azure Firewall (optional) | `azurerm_firewall` | Central network filtering | ~$912 |
| VPN Gateway (optional) | `azurerm_virtual_network_gateway` | Hybrid connectivity | ~$138 |
| Azure Bastion (optional) | `azurerm_bastion_host` | Secure VM access | ~$138 |

### Module 12 — Migration

| Resource | Azure Resource Type | Purpose | Est. Monthly Cost |
|----------|-------------------|---------|-------------------|
| Resource Group | `azurerm_resource_group` | Migration resources container | Free |
| Azure Migrate Project | `azurerm_resource_group_template_deployment` | Assessment and discovery | Free |
| Recovery Services Vault | `azurerm_recovery_services_vault` | ASR replication target | ~$10–25 |
| Database Migration Service | `azurerm_database_migration_service` | SQL migration tooling | ~$40–80 |
| Staging Storage Account | `azurerm_storage_account` | ASR replication cache | ~$1–3 |
| Simulated On-Prem VM | `azurerm_linux_virtual_machine` | Migration source (demo) | ~$7.60 |

> \* Free with Entra ID Free tier; Conditional Access requires P1+ license.
> \** Log ingestion costs are billed through the Log Analytics Workspace (Module 00).

---

## 4. Dependency Map

```mermaid
flowchart TD
    M00["Module 00<br/>Foundation"]

    M01["Module 01<br/>Governance"]
    M02["Module 02<br/>Identity"]
    M03["Module 03<br/>Key Vault"]
    M04["Module 04<br/>Monitoring"]
    M05["Module 05<br/>HA/DR"]
    M06["Module 06<br/>Storage"]
    M07["Module 07<br/>Databases"]
    M08["Module 08<br/>Data Integration"]
    M09["Module 09<br/>Compute"]
    M10["Module 10<br/>App Architecture"]
    M11["Module 11<br/>Networking"]
    M12["Module 12<br/>Migration"]

    M00 --> M01
    M00 --> M02
    M00 --> M03
    M00 --> M04
    M00 --> M05
    M00 --> M06
    M00 --> M07
    M00 --> M08
    M00 --> M09
    M00 --> M10
    M00 --> M11
    M00 --> M12

    M03 -.->|optional: KV metrics| M04
    M06 -.->|storage patterns| M07
    M04 -.->|App Insights| M09
    M06 -.->|Data Lake| M08
    M07 -.->|SQL target| M12

    style M00 fill:#47a,stroke:#333,color:#fff
    style M03 fill:#a74,stroke:#333,color:#fff
    style M04 fill:#e74,stroke:#333,color:#fff
```

### Dependency Details

| Module | Hard Dependencies | Soft / Optional References |
|--------|-------------------|---------------------------|
| **00 — Foundation** | None (root module) | — |
| **01 — Governance** | 00: resource group, subscription | — |
| **02 — Identity** | 00: resource group, LAW | — |
| **03 — Key Vault** | 00: VNet, keyvault subnet, LAW | — |
| **04 — Monitoring** | 00: resource group, LAW | 03: Key Vault metrics (optional) |
| **05 — HA/DR** | 00: compute subnet, LAW | — |
| **06 — Storage** | 00: VNet, storage subnet, LAW | — |
| **07 — Databases** | 00: VNet, database subnet, LAW | 06: storage patterns reference |
| **08 — Data Integration** | 00: VNet, data-integration subnet, LAW | 06: Data Lake Gen2 |
| **09 — Compute** | 00: VNet, compute subnet, LAW | 04: Application Insights |
| **10 — App Architecture** | 00: LAW | — |
| **11 — Networking** | 00: VNet (for peering) | — |
| **12 — Migration** | 00: VNet, migration subnet, LAW | 07: SQL target for DMS |

---

## 5. Network Topology Diagram

```mermaid
flowchart TB
    subgraph PrimaryVNet["Foundation VNet — 10.0.0.0/16"]
        direction TB
        S0["default<br/>10.0.0.0/24<br/>🔒 NSG attached"]
        S1["governance<br/>10.0.1.0/24"]
        S2["identity<br/>10.0.2.0/24"]
        S3["keyvault<br/>10.0.3.0/24<br/>🔗 PE: Key Vault"]
        S4["monitoring<br/>10.0.4.0/24"]
        S5["compute<br/>10.0.5.0/24<br/>⚖️ LB + VMs"]
        S6["storage<br/>10.0.6.0/24<br/>🔗 PE: Storage"]
        S7["database<br/>10.0.7.0/24<br/>🔗 PE: SQL Server"]
        S8["data-integration<br/>10.0.8.0/24"]
        S9["app-architecture<br/>10.0.9.0/24"]
        S10["networking<br/>10.0.10.0/24"]
        S11["migration<br/>10.0.11.0/24"]
        S250["AzureBastionSubnet<br/>10.0.250.0/24"]
        S251["GatewaySubnet<br/>10.0.251.0/24"]
    end

    subgraph SecondaryVNet["Secondary VNet — 10.1.0.0/16 (Module 11)"]
        S1_0["Workload Subnets"]
        NSG11["NSG + ASG Rules"]
        RT11["Route Table"]
    end

    PrimaryVNet <-->|"VNet Peering<br/>Bidirectional"| SecondaryVNet

    subgraph PrivateEndpoints["Private Endpoints"]
        PE_KV["PE: Key Vault<br/>privatelink.vaultcore.azure.net"]
        PE_SA["PE: Storage<br/>privatelink.blob.core.windows.net"]
        PE_SQL["PE: SQL Server<br/>privatelink.database.windows.net"]
    end

    S3 --- PE_KV
    S6 --- PE_SA
    S7 --- PE_SQL

    subgraph LoadBalancers["Load Balancers (compute subnet)"]
        PLB["Public LB<br/>Standard · Static PIP"]
        ILB["Internal LB<br/>Standard · Private IP"]
    end

    S5 --- PLB
    S5 --- ILB

    subgraph ExternalIngress["External Ingress"]
        TM["Traffic Manager<br/>DNS: Performance routing"]
        PIP["Public IP"]
    end

    TM -->|endpoint| PIP
    PIP --> PLB

    PLB -->|HTTP:80| VM1["VM 1"]
    PLB -->|HTTP:80| VM2["VM 2"]
    ILB -.->|internal traffic| S5
```

---

## 6. Exam Domain Mapping

The AZ-305 exam is organized into four weighted domains. Each lab module maps to one or more domains:

| Exam Domain | Weight | Modules | Key Resources |
|-------------|--------|---------|---------------|
| **Design identity, governance, and monitoring solutions** | 25–30% | 01 (Governance), 02 (Identity), 04 (Monitoring) | Policy definitions & assignments, custom RBAC role, management groups, resource locks, Entra ID groups, app registration, service principal, managed identity, conditional access, Application Insights, action groups, metric/log/activity alerts, dashboard, diagnostic settings |
| **Design data storage solutions** | 20–25% | 03 (Key Vault), 06 (Storage), 07 (Databases) | Key Vault (secrets, keys, certs, RBAC auth, private endpoint), GPv2/Premium/Data Lake storage accounts, blob containers, file shares, lifecycle management, managed disks, SQL Server (DTU + serverless vCore), elastic pool, CosmosDB (serverless) |
| **Design business continuity solutions** | 15–20% | 05 (HA/DR), 12 (Migration) | Availability sets & zones, public/internal load balancers, Recovery Services Vault, VM backup policies, Traffic Manager (performance routing), Azure Migrate, Database Migration Service, ASR replication |
| **Design infrastructure solutions** | 25–30% | 00 (Foundation), 08 (Data Integration), 09 (Compute), 10 (App Architecture), 11 (Networking) | VNet with 14 subnets, NSG, Data Factory (pipelines, linked services), Data Lake medallion architecture, Event Grid, Linux VMs, App Service, Container Instances, Container Registry, Function Apps, Batch, Event Hubs, Service Bus (queues + topics), API Management, Redis Cache, VNet peering, route tables, ASG, private DNS zones, (optional: Firewall, VPN Gateway, Bastion) |

### Module-to-Domain Cross-Reference

| Module | Identity/Governance/Monitoring | Data Storage | Business Continuity | Infrastructure |
|--------|:---:|:---:|:---:|:---:|
| 00 — Foundation | | | | ✅ |
| 01 — Governance | ✅ | | | |
| 02 — Identity | ✅ | | | |
| 03 — Key Vault | | ✅ | | |
| 04 — Monitoring | ✅ | | | |
| 05 — HA/DR | | | ✅ | |
| 06 — Storage | | ✅ | | |
| 07 — Databases | | ✅ | | |
| 08 — Data Integration | | | | ✅ |
| 09 — Compute | | | | ✅ |
| 10 — App Architecture | | | | ✅ |
| 11 — Networking | | | | ✅ |
| 12 — Migration | | | ✅ | |
