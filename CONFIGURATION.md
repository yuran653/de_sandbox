# Infrastructure Architecture for AI Coding Agents

## Purpose
This document defines the runtime, data, and network architecture intended to be consumed by **coding AI agents** (code generation, orchestration, data processing, and analytics agents).  
It is **descriptive, not prescriptive**.

---

## High-Level Topology

- **Cloud Provider**: DigitalOcean
- **Network Model**: Private network `10.104.0.0/24`
- **Public Entry Point**: `vps_1` only
- **Isolation Strategy**:
  - Docker for stateful services
  - Kubernetes for distributed compute
- **Trust Boundary**: Internet → `vps_1` → internal private network

---

## Nodes Overview

| Node | Private IP | Role |
|-----|------------|------|
| vps_1 | 10.104.0.2 | Edge, control plane, orchestration |
| vps_2 | 10.104.0.3 | Distributed compute (Spark) |
| vps_3 | 10.104.0.4 | Analytical storage (ClickHouse) |

---

## vps_1 — Edge & Orchestration Node

**OS**: Debian 12  
**Runtime**: Docker Engine  
**External Access**: Yes (single ingress point)

### Responsibilities
- Secure ingress from the public internet
- Workflow orchestration
- Transactional and metadata storage
- Object storage abstraction
- VPN gateway for private network access

### Installed Services (Docker Containers)

| Service | Purpose |
|------|--------|
| OpenVPN | Secure access to private network |
| Apache Airflow | Workflow orchestration and scheduling |
| PostgreSQL (Airflow Meta DB) | Airflow metadata |
| PostgreSQL (OLTP) | Operational / source-of-truth data |
| S3-compatible storage | Object storage for datasets, artifacts |

### AI-Agent-Relevant Capabilities
- DAG-based job control (Airflow)
- Central coordination point
- Credentials and secret distribution
- Dataset staging (S3-compatible)

---

## vps_2 — Distributed Compute Node

**OS**: Debian 12  
**Runtime**: Kubernetes  
**External Access**: No (private network only)

### Responsibilities
- Large-scale data processing
- Interactive analytics and experimentation
- Parallel computation

### Deployed Workloads

| Component | Purpose |
|---------|--------|
| Apache Spark (Kubernetes) | Batch & distributed processing |
| Jupyter Notebook | Interactive development and analysis |

### AI-Agent-Relevant Capabilities
- Programmatic Spark job submission
- Scalable compute for transformations and ML prep
- Notebook-driven experimentation
- Stateless execution model

---

## vps_3 — Analytical Storage Node

**OS**: Debian 12  
**Runtime**: Docker Engine  
**External Access**: No (private network only)

### Responsibilities
- High-performance analytical queries
- Columnar storage for large datasets

### Deployed Services

| Service | Purpose |
|-------|--------|
| ClickHouse (2 shards) | Distributed OLAP storage |

### AI-Agent-Relevant Capabilities
- Fast analytical queries
- Read-optimized workloads
- Suitable for feature generation and reporting layers

---

## Network & Security Model

### Network
- All nodes connected via **private network**
- No east–west traffic exposed publicly
- Single north–south ingress via `vps_1`

### Security Controls
- VPN-based administrative access
- No public exposure of databases or Spark
- Logical separation by runtime (Docker vs Kubernetes)

---

## Data Flow (Conceptual)

```

Internet
|
v
[vps_1]

* API / Airflow / S3 / OLTP
  |
  | private network
  v
  [vps_2] <--> [vps_3]
  Spark        ClickHouse

```

---

## AI Agent Interaction Model

### Control Plane
- AI agents interact **only with vps_1** directly
- All orchestration and scheduling routed via Airflow

### Data Plane
- Raw and intermediate data: S3-compatible storage
- Analytical queries: ClickHouse
- Heavy computation: Spark on Kubernetes

### Execution Constraints
- No direct public access to compute or analytics nodes
- Deterministic, reproducible execution via orchestration

---

## Non-Goals / Explicit Exclusions

- No multi-region deployment
- No auto-scaling beyond Kubernetes defaults
- No real-time streaming (batch-oriented architecture)
- No direct agent-to-database public access

---

## Summary

This architecture provides:
- **Clear trust boundaries**
- **Single controlled ingress**
- **Separation of concerns** (orchestration, compute, storage)
- **Deterministic execution paths** suitable for AI coding agents

It is optimized for **data engineering, analytics, and agent-driven automation**, not for low-latency serving.