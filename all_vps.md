# VPS Infrastructure Resource Analysis

## Overview
Three separate VPS instances, each running different data engineering infrastructure components:
- **VPS 1**: Airflow, PostgreSQL, and MinIO (Data Orchestration & Storage)
- **VPS 2**: ClickHouse Cluster with Zookeeper (Analytics Database)
- **VPS 3**: Apache Spark Cluster with Jupyter (Distributed Processing)

---

## VPS 1: Airflow, PostgreSQL & MinIO (`airflow_pg_s3`)

**Architecture**: Docker Compose (containerized)

### Services Overview

| Service | Type | Container | CPU Limit | Memory Limit | Purpose |
|---------|------|-----------|-----------|--------------|---------|
| airflow-webserver | Application | airflow-custom:2.8.4-python3.11 | 0.3 cores | 800 MB | Web UI for DAG management & monitoring |
| airflow-scheduler | Application | airflow-custom:2.8.4-python3.11 | 0.8 cores | 1.5 GB | DAG scheduling & task execution engine |
| metadata-db | Database | postgres:16-alpine3.21 | 0.2 cores | 256 MB | Airflow metadata storage (port 5433) |
| datalake-db | Database | postgres:16-alpine3.21 | 0.3 cores | 512 MB | Main data storage |
| minio | Object Storage | minio/minio:RELEASE.2025-09-07 | 0.2 cores | 512 MB | S3-compatible object storage |
| airflow-init | Utility | airflow-custom:2.8.4-python3.11 | - | - | One-time DB initialization |

### Resource Allocation Summary

| Resource | Total |
|----------|-------|
| **Total CPU Cores** | 1.8 cores |
| **Total Memory** | 3.6 GB |

### Detailed Resource Breakdown

#### Compute Services
- **airflow-scheduler**: 0.8 CPU / 1.5 GB - Primary workload consumer
- **airflow-webserver**: 0.3 CPU / 800 MB - UI access & DAG parsing

#### Database Services
- **metadata-db** (PostgreSQL): 0.2 CPU / 256 MB - Airflow internal state
- **datalake-db** (PostgreSQL): 0.3 CPU / 512 MB - Application data

#### Storage Services
- **minio**: 0.2 CPU / 512 MB - S3-compatible object storage

### Volume Mounts

| Volume | Mount Point | Local Device |
|--------|------------|--------------|
| airflow_dags | /opt/airflow/dags | /airflow/dags |
| airflow_logs | /opt/airflow/logs | /airflow/logs |
| airflow_plugins | /opt/airflow/plugins | /airflow/plugins |
| airflow_scripts | /opt/airflow/scripts | /airflow/scripts |
| spark_events | /var/spark-events | /spark_events |
| pg_metadata | PostgreSQL data | /pg_metadata |
| pg_datalake | PostgreSQL data | /pg_datalake |
| minio_datalake | MinIO storage | /minio_datalake |

---

## VPS 2: ClickHouse Cluster (`clickhouse`)

**Architecture**: Docker Compose with Zookeeper coordination

### Services Overview

| Service | Type | Container | CPU Limit | Memory Limit | Purpose |
|---------|------|-----------|-----------|--------------|---------|
| clickhouse-01 | Database | clickhouse:24.8 | 0.9 cores | 1.8 GB | ClickHouse node 1 (port 9000) |
| clickhouse-02 | Database | clickhouse:24.8 | 0.9 cores | 1.8 GB | ClickHouse node 2 (port 19000) |
| zookeeper | Coordination | custom-zookeeper:3.7 | 0.1 cores | 512 MB | Cluster coordination & replication |
| clickhouse-init-db | Utility | clickhouse:24.8 | - | - | One-time database initialization |

### Resource Allocation Summary

| Resource | Total |
|----------|-------|
| **Total CPU Cores** | 1.9 cores |
| **Total Memory** | 4.1 GB |

### Detailed Resource Breakdown

#### Database Nodes (Replicated)
- **clickhouse-01**: 0.9 CPU / 1.8 GB - Primary analytics node
- **clickhouse-02**: 0.9 CPU / 1.8 GB - Replicated analytics node

#### Coordination
- **zookeeper**: 0.1 CPU / 512 MB - Manages replication state

### Volume Mounts

| Volume | Mount Point | Local Device |
|--------|------------|--------------|
| ch01_data | /var/lib/clickhouse | /clickhouse/01/data |
| ch01_logs | /var/log/clickhouse-server | /clickhouse/01/logs |
| ch02_data | /var/lib/clickhouse | /clickhouse/02/data |
| ch02_logs | /var/log/clickhouse-server | /clickhouse/02/logs |
| zk_data | /data | /clickhouse/zk/data |
| zk_logs | /datalog | /clickhouse/zk/logs |

---

## VPS 3: Apache Spark Cluster (`spark`)

**Architecture**: Kubernetes (StatefulSet & Deployment)  
**Namespace**: spark  
**Storage Class**: local-path

### Services Overview

| Service | Type | Replicas | CPU Requests | CPU Limits | Memory Requests | Memory Limits | Purpose |
|---------|------|----------|--------------|-----------|-----------------|---------------|---------|
| spark-master | StatefulSet | 1 | 500m | 600m | 1024 Mi | 1280 Mi | Cluster manager (port 7077) |
| spark-worker | StatefulSet | 2 | 1200m ea | 1400m ea | 2560 Mi ea | 2816 Mi ea | Worker nodes (webui: 30081-30082) |
| spark-jupyter | Deployment | 1 | 400m | 500m | 768 Mi | 1024 Mi | Jupyter Lab notebook environment (port 8888) |

### Resource Allocation Summary

| Metric | Requests | Limits |
|--------|----------|--------|
| **Total CPU** | 3.3 cores | 3.9 cores |
| **Total Memory** | 6.9 GB | 7.7 GB |

### Detailed Resource Breakdown

#### Master Node
- **spark-master** (1 replica)
  - CPU: 500m requests / 600m limits
  - Memory: 1024 Mi requests / 1280 Mi limits
  - Environment: SPARK_DAEMON_MEMORY=768m
  - Public DNS: 10.104.0.4

#### Worker Nodes (Scaled)
- **spark-worker** (2 replicas)
  - Per-node CPU: 1200m requests / 1400m limits
  - Per-node Memory: 2560 Mi requests / 2816 Mi limits
  - Configured cores per worker: 1
  - Configured memory per worker: 2g
  - Total: 2400m CPU requests / 2.8 cores CPU limits, 5 GB / 5.5 GB memory

#### Notebook Server
- **spark-jupyter** (1 replica)
  - CPU: 400m requests / 500m limits
  - Memory: 768 Mi requests / 1024 Mi limits
  - Driver Memory: 768m
  - Python: 3.11

### Volume Mounts (Persistent)

| PVC | Mount Point | Storage Request | Node |
|-----|------------|-----------------|------|
| spark-events (master) | /var/spark-events | 1 Gi | spark-master-0 |
| spark-events (worker) | /var/spark-events | 1 Gi per worker | spark-worker-0, spark-worker-1 |
| jupyter-notebooks | /opt/spark/notebooks | - | spark-jupyter |
| spark-events (jupyter) | /var/spark-events | - | spark-jupyter |

---

## Comparative Analysis

### CPU Allocation

| VPS | Service Type | CPU Cores | % of Total |
|-----|--------------|-----------|-----------|
| VPS 1 (Airflow) | Orchestration | 1.8 | ~49% |
| VPS 2 (ClickHouse) | Analytics DB | 1.9 | ~52% |
| VPS 3 (Spark) | Processing (Requests) | 3.3 | ~90% |
| VPS 3 (Spark) | Processing (Limits) | 3.9 | ~106% |

### Memory Allocation

| VPS | Service Type | Memory (GB) | % of Total |
|-----|--------------|------------|-----------|
| VPS 1 (Airflow) | Orchestration | 3.6 | ~42% |
| VPS 2 (ClickHouse) | Analytics DB | 4.1 | ~48% |
| VPS 3 (Spark) | Processing (Requests) | 6.9 | ~80% |
| VPS 3 (Spark) | Processing (Limits) | 7.7 | ~89% |

### Total Infrastructure Requirements

| Metric | Value |
|--------|-------|
| **Total CPU (Docker)** | 5.6 cores (VPS 1 + VPS 2) |
| **Total Memory (Docker)** | 7.7 GB (VPS 1 + VPS 2) |
| **Spark CPU Requests** | 3.3 cores |
| **Spark Memory Requests** | 6.9 GB |
| **Spark CPU Limits** | 3.9 cores |
| **Spark Memory Limits** | 7.7 GB |

---

## Service Dependencies

### VPS 1 (Airflow) Startup Order
1. zookeeper (external, assumed running)
2. metadata-db (PostgreSQL)
3. minio (S3 storage)
4. datalake-db (PostgreSQL)
5. airflow-init (system initialization)
6. airflow-scheduler (depends on airflow-init)
7. airflow-webserver (depends on scheduler)

### VPS 2 (ClickHouse) Startup Order
1. zookeeper (built-in)
2. clickhouse-01 (primary node)
3. clickhouse-02 (depends on clickhouse-01)
4. clickhouse-init-db (depends on clickhouse-02)

### VPS 3 (Spark) Startup Order
1. spark-master (StatefulSet replicas)
2. spark-worker (waits for master via init container)
3. spark-jupyter (independent)

---

## Networking Configuration

### VPS 1 & 2
- **Mode**: Docker host networking
- **Port Isolation**: Via port number assignment
- **Airflow Ports**: 8080 (webserver), 5433 (metadata)
- **ClickHouse Ports**: 9000 (data), 19000 (replica), 2181 (zookeeper)
- **MinIO Ports**: 9000 (API), 9001 (console)

### VPS 3 (Kubernetes)
- **Namespace**: spark
- **Service Discovery**: DNS via cluster.local domain
- **Master Service**: spark-master-0.spark-master-headless.spark.svc.cluster.local:7077
- **NodePort Services**: 30080 (master UI), 30081-30082 (worker UIs), 8888 (Jupyter)

---

## Performance Characteristics

### VPS 1: Balanced Compute & Storage
- **Strength**: Flexible workflow engine with metadata management
- **Bottleneck**: Single scheduler (0.8 CPU), suitable for small-to-medium DAGs
- **Storage**: S3-compatible, suitable for data lakes

### VPS 2: Analytics Optimized
- **Strength**: Replicated ClickHouse cluster for high availability
- **Bottleneck**: CPU per node may bottleneck complex analytical queries
- **Storage**: Distributed, replicated across 2 nodes

### VPS 3: Distributed Processing
- **Strength**: Scales horizontally with Kubernetes
- **Configuration**: 2 worker nodes with 1 core each, suitable for parallel tasks
- **Interactive**: Jupyter for exploratory analysis
- **Limitation**: Resource requests conservative; limits allow burst processing

---

## Recommendations

### Resource Scaling
- **Short-term**: VPS 1 scheduler is the most utilized; consider increasing if DAG queue grows
- **Long-term**: Spark cluster can scale by increasing worker replicas

### High Availability
- ClickHouse: Already configured with 2-node replication
- Airflow: Metadata-db is single point of failure (consider external managed DB)

### Monitoring Priorities
- Scheduler queue depth in VPS 1 (indicates if CPU is constraining DAG execution)
- ClickHouse query response times under load in VPS 2
- Spark task completion time and resource utilization in VPS 3
