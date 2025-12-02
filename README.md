# Revolutionize Your Data Engineering Workflow with DE Sandbox

DE Sandbox is a Docker-based data engineering environment for Debian 12 hosts, integrating Apache Airflow 2.8.4 for workflow orchestration, Apache Spark 3.4.4 cluster for distributed processing, and ClickHouse 24.8 cluster for OLAP analytics. It includes PostgreSQL databases for metadata and datalake storage, MinIO for S3-compatible object storage, and mandatory WireGuard VPN for secure remote access. Designed for experimentation, prototyping, and training, it ensures stability with pinned versions and automated deployment scripts.

## Why Choose DE Sandbox?
- **All-in-One Solution**: Seamlessly integrate Airflow DAGs with Spark jobs and ClickHouse analytics in a unified Docker environment, eliminating setup complexity.
- **Perfect for Lightweight Demos, Presentations, and Pet Projects**: Simulates real-job data engineering workflows for authentic prototyping and demonstrations without full-scale infrastructure.
- **Production-Ready**: Pre-configured with resource limits, health checks, and persistent volumes.
- **Secure Networking**: WireGuard VPN with nftables firewall for controlled access.
- **Automated Setup**: Scripts handle Docker installation and service deployment.

## Key Features
- **Airflow Platform** (`airflow_pg_s3/`): Custom Airflow 2.8.4 image with essential providers, PostgreSQL metadata store, datalake database, and MinIO object storage for S3-compatible operations.
- **Spark Cluster** (`spark/`): Standalone Spark 3.4.4 cluster with master, two workers, and history server, sharing event logs for job tracking.
- **ClickHouse Cluster** (`clickhouse/`): Distributed ClickHouse 24.8 setup with two nodes and Zookeeper for coordination, enabling high-performance OLAP queries.
- **Security & Networking**: WireGuard VPN installer with nftables firewall, exposing only necessary ports and routing Docker traffic securely.
- **Automation & Stability**: Bootstrap scripts for Docker, Docker Compose, and component deployment, with version locking to prevent unexpected breaks.

## Usage Scenarios
- Develop and test Airflow DAGs with Postgres, MinIO, Spark, and ClickHouse integrations.
- Prototype Spark applications against shared storage and analyze in ClickHouse.
- Deploy consistent environments for training sessions or client demonstrations.
- Enable secure remote collaboration via VPN.

## Project Structure
- `airflow_pg_s3/`
  - `airflow/`: Custom Airflow image build (Dockerfile, requirements.txt, environment configs).
  - `docker-compose.yaml`: Orchestrates Airflow scheduler/webserver, PostgreSQL databases, and MinIO.
  - `install.sh`: Comprehensive installer for WireGuard, Docker, and Airflow stack.
  - `etc/`: Firewall configs and helper scripts.
  - `scripts/`: Additional deployment and setup scripts.
- `spark/`
  - `docker-compose.yaml`: Defines Spark master, workers, and history server.
  - `install.sh`: Docker bootstrap and Spark service launcher.
  - `build/`, `master/`, `workers/`, `hist-server/`: Docker build and configuration overrides.
  - `scripts/`: Setup utilities.
- `clickhouse/`
  - `docker-compose.yaml`: Configures two-node ClickHouse cluster with Zookeeper and shared configs.
  - `install.sh`: Docker and ClickHouse deployment script.
  - `etc/`: Node-specific and cluster configurations.
  - `scripts/`: Routing and installation helpers.

## Quick Start Guide
1. **Prepare Your Environment**: Ensure you have a Debian 12 machine with sudo privileges and at least 8GB RAM + 50GB disk space.
2. **Deploy Airflow Stack**: Run `airflow_pg_s3/install.sh` to install WireGuard, Docker, and launch Airflow with persistent volumes (`/airflow/*`, `/pg_*`, `/minio_datalake`).
2. **Launch Spark Cluster**: Execute `spark/install.sh` to install Docker, set up routing, and start Spark services, creating `/spark_events` for logs.
4. **Set Up ClickHouse**: Use `clickhouse/install.sh` for Docker installation, routing setup, and cluster initialization.
5. **Access Interfaces**:
   - Airflow UI: `http://<host>:8080` (credentials in `airflow_pg_s3/airflow/.env`)
   - Spark Master: `http://<host>:8080`, Workers: 8081/8082, History: `http://<host>:18080`
   - ClickHouse: TCP 9000 (node1), 19000 (node2); HTTP 8123 (node1), 18123 (node2)
   - MinIO Console: `http://<host>:9001`

## Advanced Configuration
- **VPN Setup**: After running `install.sh`, add client peers to `/etc/wireguard/de_sandbox.conf` for remote access.
- **Custom DAGs/Plugins**: Mount or add to `/airflow/dags` and `/airflow/plugins`.
- **Spark Tuning**: Edit configs in `spark/*/spark-defaults.conf` before deployment.
- **ClickHouse Queries**: Use `clickhouse-client` to interact; cluster configs in `etc/`.
- **Firewall Rules**: Modify `airflow_pg_s3/etc/nftables.conf` for custom networking.

## Maintenance & Troubleshooting
- **Rebuild Images**: After dependency changes, run `docker compose build` in respective directories.
- **Logs & Monitoring**: Use `docker compose logs -f <service>` for real-time logs.
- **Resource Allocation**: Adjust CPU/memory limits in `docker-compose.yaml` based on host capacity.
- **Persistence**: Volumes are bind-mounted to host paths; ensure backups for critical data.
- **Updates**: Pinned versions ensure consistency; test upgrades in a separate environment.

Dive into Data Engineering today and transform the way you build data pipelines—fast, secure, and scalable!
