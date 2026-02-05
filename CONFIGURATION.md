# System Architecture Description (for Coding AI Agents)

## 1. Overview

The system consists of three Virtual Private Servers (VPS) deployed in DigitalOcean.  
The architecture follows a **single-entry-point** model, where all external network access is terminated on `vps_1`. Internal communication between components occurs over private networking.

The platform is designed to support:
- Workflow orchestration
- OLTP storage
- Analytical processing
- Distributed computation with Spark
- Object storage (S3-compatible)
- Secure remote access

---

## 2. Network Topology

- **Public Internet Access**: Only `vps_1` is exposed.
- **Internal Traffic**: `vps_1`, `vps_2`, and `vps_3` communicate via private IPs.
- **Security Boundary**:
  - OpenVPN runs on `vps_1` and provides controlled access to internal services.
  - No direct inbound access to `vps_2` or `vps_3`.

---

## 3. VPS Roles and Responsibilities

### 3.1 vps_1 — Control Plane & Entry Point

**OS**: Debian 12  
**Runtime**: Docker Engine

**Responsibilities**:
- Single ingress point from the internet
- Orchestration and control services
- Metadata and transactional workloads
- Object storage

**Services (Docker containers)**:
- **Apache Airflow**
  - DAG orchestration
  - Task scheduling
  - Triggers Spark jobs on `vps_2`
- **PostgreSQL (Airflow Metadata DB)**
  - Stores Airflow state, DAG runs, task instances
- **PostgreSQL (OLTP)**
  - Application-level transactional data
- **S3-compatible Object Storage**
  - Shared storage for:
    - Spark input/output
    - Intermediate datasets
    - Artifacts and logs
- **OpenVPN**
  - Secure access to internal services
  - Acts as a bastion / gateway

---

### 3.2 vps_2 — Distributed Compute

**OS**: Debian 12  
**Runtime**: Kubernetes

**Responsibilities**:
- Distributed data processing
- Scalable batch and analytical computation

**Services**:
- **Apache Spark on Kubernetes**
  - Spark drivers and executors run as pods
  - Jobs are submitted remotely (e.g., from Airflow)
  - Reads from / writes to:
    - S3-compatible storage on `vps_1`
    - ClickHouse on `vps_3`

**Key Characteristics**:
- Stateless compute
- Horizontally scalable via Kubernetes
- No direct internet exposure

---

### 3.3 vps_3 — Analytical Storage

**OS**: Debian 12  
**Runtime**: Docker Engine

**Responsibilities**:
- Analytical querying
- High-performance OLAP workloads

**Services (Docker containers)**:
- **ClickHouse (2 shards)**
  - Sharded deployment for horizontal scalability
  - Used for:
    - Aggregations
    - Analytical queries
    - Reporting workloads

**Access Pattern**:
- Written to by Spark jobs (`vps_2`)
- Queried by:
  - Airflow tasks
  - Internal consumers via VPN

---

## 4. Data Flow

1. **Ingestion**
   - Data arrives via Airflow-triggered jobs or external sources.
   - Raw data stored in S3-compatible storage on `vps_1`.

2. **Processing**
   - Airflow schedules Spark jobs.
   - Spark runs on Kubernetes (`vps_2`).
   - Spark reads input from S3 and processes data.

3. **Storage**
   - Processed data is:
     - Written back to S3 (intermediate / archival)
     - Loaded into ClickHouse (`vps_3`) for analytics
     - Optionally written to PostgreSQL OLTP (`vps_1`)

4. **Analytics**
   - ClickHouse serves low-latency analytical queries.
   - Results may be consumed by downstream systems or workflows.

---

## 5. Architectural Constraints (Explicit)

- Single public entry point: `vps_1`
- No direct internet access to compute (`vps_2`) or analytics (`vps_3`)
- Stateless compute, stateful storage
- Clear separation of concerns:
  - Orchestration → `vps_1`
  - Compute → `vps_2`
  - Analytics → `vps_3`

---

## 6. Intended Usage by AI Agents

AI agents interacting with this system should assume:
- All external API calls and job submissions are routed via `vps_1`
- Long-running or heavy computation is delegated to Spark on `vps_2`
- Analytical queries target ClickHouse on `vps_3`
- Shared datasets are exchanged through S3-compatible storage
- No agent should assume direct access to internal nodes without VPN context
