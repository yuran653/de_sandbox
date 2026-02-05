# Revolutionize Your Data Engineering Workflow with DE Sandbox

DE Sandbox is a Docker-based data engineering environment for Debian 12 hosts, integrating Apache Airflow 2.8.4 for workflow orchestration, Apache Spark 3.4.4 cluster for distributed processing, and ClickHouse 24.8 cluster for OLAP analytics. It includes PostgreSQL databases for metadata and datalake storage, MinIO for S3-compatible object storage, and mandatory WireGuard VPN for secure remote access. Designed for experimentation, prototyping, and training, it ensures stability with pinned versions and automated deployment scripts.

**NEW**: Now supports **distributed multi-VPS deployment** on DigitalOcean! Deploy across three VPS instances with automatic networking and service discovery. See [deployment/README.md](deployment/README.md) for details.

## Why Choose DE Sandbox?
- **All-in-One Solution**: Seamlessly integrate Airflow DAGs with Spark jobs and ClickHouse analytics in a unified Docker environment, eliminating setup complexity.
- **Flexible Deployment**: Single-host setup for local development or distributed multi-VPS deployment for production-like environments.
- **Perfect for Lightweight Demos, Presentations, and Pet Projects**: Simulates real-job data engineering workflows for authentic prototyping and demonstrations without full-scale infrastructure.
- **Production-Ready**: Pre-configured with resource limits, health checks, and persistent volumes.
- **Secure Networking**: WireGuard VPN with nftables firewall for controlled access. Private network isolation in multi-VPS setup.
- **Automated Setup**: Scripts handle Docker installation and service deployment for both single-host and multi-VPS configurations.

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
- `deployment/` *(NEW)*
  - `README.md`: Comprehensive multi-VPS deployment guide.
  - `NETWORK_SETUP.md`: DigitalOcean VPC and network configuration instructions.
  - `vps1-deploy.sh`, `vps2-deploy.sh`, `vps3-deploy.sh`: VPS-specific deployment scripts.
  - `*.env.template`: Environment configuration templates for each VPS.
- `examples/` *(NEW)*
  - `dags/`: Example Airflow DAGs demonstrating multi-VPS data pipelines.
  - `README.md`: Guide to using and creating example DAGs.
- `CONFIGURATION.md`: Architecture overview for multi-VPS deployment.
- `PLAN.md`: Detailed implementation plan and steps.

## Quick Start Guide

### Single-Host Deployment (Development)
1. **Prepare Your Environment**: Ensure you have a Debian 12 machine with sudo privileges and at least 8GB RAM + 50GB disk space.
2. **Deploy Airflow Stack**: Run `airflow_pg_s3/install.sh` to install WireGuard, Docker, and launch Airflow with persistent volumes (`/airflow/*`, `/pg_*`, `/minio_datalake`).
3. **Launch Spark Cluster**: Execute `spark/install.sh` to install Docker, set up routing, and start Spark services, creating `/spark_events` for logs.
4. **Set Up ClickHouse**: Use `clickhouse/install.sh` for Docker installation, routing setup, and cluster initialization.
5. **Access Interfaces**:
   - Airflow UI: `http://<host>:8080` (credentials in `airflow_pg_s3/airflow/.env`)
   - Spark Master: `http://<host>:8080`, Workers: 8081/8082, History: `http://<host>:18080`
   - ClickHouse: TCP 9000 (node1), 19000 (node2); HTTP 8123 (node1), 18123 (node2)
   - MinIO Console: `http://<host>:9001`

### Multi-VPS Deployment (Production)
For distributed deployment across three DigitalOcean VPS instances:
1. **Review Architecture**: Read [CONFIGURATION.md](CONFIGURATION.md) and [PLAN.md](PLAN.md) for architecture overview
2. **Setup Network**: Follow [deployment/NETWORK_SETUP.md](deployment/NETWORK_SETUP.md) to configure VPC and private network
3. **Deploy Services**: Use deployment scripts in order:
   - VPS 1 (Ingress): `deployment/vps1-deploy.sh`
   - VPS 3 (Analytics): `deployment/vps3-deploy.sh`
   - VPS 2 (Compute): `deployment/vps2-deploy.sh`
4. **Configure VPN**: Setup WireGuard on VPS 1 for secure access
5. **Test Pipeline**: Use example DAGs in `examples/dags/` to verify end-to-end connectivity

See [deployment/README.md](deployment/README.md) for detailed multi-VPS deployment instructions.

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
