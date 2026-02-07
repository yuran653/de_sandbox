# System Architecture Overview

## High-Level Topology

The system is deployed on **DigitalOcean** and consists of **three VPS instances** connected via a **WireGuard VPN network (10.10.0.0/24)** with a centralized gateway at **10.104.0.5**.  
All **external ingress traffic** is terminated on **VPS_1**, which acts as the **single entry point** to the internal infrastructure.

---

## VPS_1 — Ingress, Orchestration, OLTP, Object Storage

**Hostname / IP:** `vps_1 / 10.104.0.5`  
**OS:** Debian 12  
**Roles:**  
- Single external entry point  
- VPN gateway  
- Workflow orchestration  
- OLTP storage  
- Object storage

### Installed Services
- **Docker Engine**
- **OpenVPN**

### Dockerized Components
- **Apache Airflow**
  - Orchestrates batch and analytical workflows
- **PostgreSQL (Airflow Metadata DB)**
  - Stores Airflow state, DAG runs, task instances
- **PostgreSQL (OLTP)**
  - Primary transactional database for applications
- **S3-compatible Object Storage**
  - Centralized storage for raw and intermediate data
  - Used by Airflow and Spark jobs

### Responsibilities
- Terminates all inbound internet traffic
- Provides secure VPN access to the private network
- Acts as the control and coordination node

---

## VPS_2 — Analytical Storage Layer

**Hostname / IP:** `vps_2 / 10.104.0.2`  
**OS:** Debian 12  
**Roles:**  
- Analytical data storage
- OLAP query processing

### Installed Services
- **Docker Engine**

### Dockerized Components
- **ClickHouse (2 shards)**
  - Distributed analytical database
  - Optimized for high-throughput analytical queries

### Responsibilities
- Serves analytical workloads
- Receives data from Spark jobs
- No direct internet exposure

---

## VPS_3 — Distributed Compute Layer

**Hostname / IP:** `vps_3 / 10.104.0.3`  
**OS:** Debian 12  
**Roles:**  
- Distributed data processing
- Interactive analytics

### Installed Services
- **K3s (Lightweight Kubernetes)**

### Kubernetes Workloads
- **Apache Spark (on Kubernetes)**
  - Batch and analytical processing
  - Reads data from S3-compatible storage
  - Writes results to ClickHouse and/or S3
- **Jupyter Notebook**
  - Interactive development and exploration
  - Spark client interface

### Responsibilities
- Executes compute-intensive workloads
- Isolated from direct internet access
- Communicates only via private network

---

## Network and Security Model

- **Single ingress point:** only `VPS_1` is exposed to the internet
- **Private inter-node communication:** WireGuard VPN network `10.10.0.0/24` with gateway at `10.104.0.5`
- **Access control:** OpenVPN/WireGuard on `VPS_1`
- **No public exposure** of Kubernetes, Spark, or ClickHouse
- **Routing configuration:** Each VPS enables IP forwarding and configures static routes for cross-VPS communication

---

## Data Flow Summary

1. External requests enter via **VPS_1**
2. Airflow triggers jobs and coordinates workflows
3. Raw/intermediate data stored in **S3-compatible storage** on VPS_1
4. Spark jobs on **VPS_3** process data via VPN network
5. Analytical results written to **ClickHouse on VPS_2**
6. OLTP workloads handled by PostgreSQL on **VPS_1**

---

## Architectural Characteristics

- Clear separation of **ingress**, **compute**, and **analytics**
- Minimal attack surface with WireGuard VPN isolation
- Suitable for batch analytics and data engineering workloads
- Scales horizontally at the compute and analytics layers
- Automated routing setup ensures reliable inter-service communication
