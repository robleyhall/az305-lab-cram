# AZ-305 CertForge Lab

This repository contains **two layers**:

1. **CertForge** — a reusable meta-prompt that turns any Azure certification cram-session video into a deployable hands-on lab.
2. **az305-lab/** — the concrete lab it produced for [John Savill's AZ-305 Study Cram](https://www.youtube.com/watch?v=vq9LuCM4YP4).

---

## How This Project Was Built

The entire lab — 193 files, 13 Terraform modules, 78 exercises, 14 architecture diagrams, and a 52 KB study guide — was generated in a single Copilot session using two inputs:

| Input | Description |
|-------|-------------|
| [certforge-prompt.md](certforge-prompt.md) | CertForge v1.1 meta-prompt (659 lines). Defines a 7-phase pipeline: source extraction → interview → transcript analysis → project generation → IaC implementation → cost management → comprehensive review. |
| [AZ-305 Transcript](AZ-305_Designing_Microsoft_Azure_Infrastructure_Solutions_Study_Cram_-_Over_100000_views.md) | 177 KB markdown transcript of the cram session, pre-extracted with MarkItDown. |

### Pipeline Phases

| Phase | What happened |
|-------|---------------|
| **0 — Source Extraction** | Fetched the YouTube description, sanitized all links (unwrapped redirects, normalized `learn.microsoft.com` URLs, stripped tracking params), parsed chapter timestamps. |
| **1 — Interview** | Collected user preferences: Terraform, East US, Realistic cost tier, Enterprise subscription. |
| **2 — Transcript Analysis** | Mapped ~2.5 hours of content to 12 topic areas, classified each as deployable / partially deployable / conceptual, and grouped chapters into modules. |
| **3 — Project Generation** | Scaffolded the full directory tree: READMEs, architecture docs, cost estimates, exercise files, Mermaid diagrams, deployment scripts. |
| **4 — Lab Study Guide** | Generated `LAB-GUIDE.md` — a 52 KB standalone study guide with exam-style questions, readiness checklist, and knowledge-gap analysis. |
| **5 — IaC Implementation** | Wrote 13 Terraform modules (`00-foundation` through `12-migration`), all passing `terraform validate`. |
| **6 — Cost Management** | Produced `COST-ESTIMATE.md`, pause/resume scripts, and per-module teardown tooling. |
| **7 — Review & Delivery** | Added practice questions, exam-readiness checklist, and cross-referenced every exercise back to exam objective domains. |

### Lessons captured along the way → [tasks/lessons.md](tasks/lessons.md)

---

## Repository Structure

```
├── README.md                      ← you are here
├── certforge-prompt.md            ← the meta-prompt (reusable for other certs)
├── AZ-305_…_Study_Cram_….md      ← source transcript
├── tasks/
│   ├── todo.md                    ← task tracker from the generation session
│   └── lessons.md                 ← mistakes & rules captured during build
└── az305-lab/                     ← the generated lab (see below)
```

---

## The Lab

> **Full documentation lives in [az305-lab/README.md](az305-lab/README.md).** Key highlights are embedded below.

### What's inside

- **13 Terraform modules** covering all four AZ-305 exam domains
- **78 guided exercises** — Portal walkthroughs, design-scenario questions, and architecture trade-off analysis (tuned to match the exam's scenario-based format)
- **14 Mermaid architecture diagrams** (overall + per-module)
- **20 scripts** — deploy, destroy, pause, resume, validate, estimate costs
- **Standalone study guide** ([LAB-GUIDE.md](az305-lab/LAB-GUIDE.md)) usable without the video

### Exam Domain Coverage

| Exam Domain | Weight | Modules |
|-------------|--------|---------|
| Design identity, governance, and monitoring | 25–30 % | 01-governance, 02-identity, 03-keyvault, 04-monitoring |
| Design data storage solutions | 20–25 % | 06-storage, 07-databases, 08-data-integration |
| Design business continuity solutions | 15–20 % | 05-ha-dr |
| Design infrastructure solutions | 30–35 % | 09-compute, 10-app-architecture, 11-networking, 12-migration |

### Quick Start

```bash
cd az305-lab

# Check prerequisites (Azure CLI, Terraform, jq, etc.)
./prerequisites/check-prerequisites.sh

# Deploy the foundation module first
cd modules/00-foundation
cp terraform.tfvars.example terraform.tfvars   # edit with your sub ID + region
terraform init && terraform apply

# Then deploy any topic module
cd ../01-governance
cp terraform.tfvars.example terraform.tfvars
terraform init && terraform apply
```

### Estimated Cost

| Scenario | Daily Cost |
|----------|------------|
| All modules running | ~$8–15 |
| Paused (non-compute only) | ~$2–4 |
| Single module | $0.10–4.00 |
| Everything destroyed | $0.00 |

### Cleanup

```bash
./scripts/destroy-all.sh          # tears down in reverse dependency order
./scripts/destroy-module.sh 05-ha-dr   # or one module at a time
```

---

## Using CertForge for Other Certifications

The meta-prompt is certification-agnostic. To generate a lab for a different exam:

1. Get a transcript of the target cram session (e.g., AZ-104, AZ-400, DP-900).
2. Open a Copilot chat, paste `certforge-prompt.md`, and provide the YouTube URL + transcript.
3. Answer the six interview questions (IaC tool, region, cost tolerance, etc.).
4. CertForge handles the rest.

See the [Phase 1 interview section](certforge-prompt.md) in the prompt for the full list of configuration options.

---

## License

MIT
