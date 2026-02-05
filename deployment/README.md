# Multi-VPS Deployment Guide

## Overview
This guide provides step-by-step instructions for deploying the distributed data engineering platform across three VPS instances on DigitalOcean.

## Prerequisites

### DigitalOcean Account Setup
- Active DigitalOcean account
- Three Debian 12 VPS instances (Droplets) provisioned
- VPC (Virtual Private Cloud) configured with CIDR 10.104.0.0/24
- SSH access to all VPS instances

### Minimum Hardware Requirements

#### VPS 1 (Ingress & Orchestration)
- 4 vCPUs
- 8 GB RAM
- 100 GB SSD
- Public IP + Private IP (10.104.0.2)

#### VPS 2 (Compute Layer)
- 8 vCPUs
- 16 GB RAM
- 160 GB SSD
- Private IP only (10.104.0.3)

#### VPS 3 (Analytics Layer)
- 4 vCPUs
- 8 GB RAM
- 100 GB SSD
- Private IP only (10.104.0.4)

## Network Configuration

### Step 1: Create VPC on DigitalOcean
1. Log into DigitalOcean Console
2. Navigate to Networking → VPC
3. Click "Create VPC Network"
4. Configure:
   - Name: `de-sandbox-vpc`
   - Region: Choose your preferred region
   - IP Range: `10.104.0.0/24`
5. Create VPC

### Step 2: Assign VPS to VPC
1. When creating droplets, select the `de-sandbox-vpc` VPC
2. Assign static private IPs:
   - VPS 1: `10.104.0.2`
   - VPS 2: `10.104.0.3`
   - VPS 3: `10.104.0.4`

### Step 3: Configure Public Access
- Only VPS 1 should have a public IP address
- VPS 2 and VPS 3 should NOT have public IPs (VPC-only)

## Deployment Order

The services must be deployed in the following order to ensure proper dependencies:

1. **VPS 1** - Deploy first (provides S3 storage and orchestration)
2. **VPS 3** - Deploy second (provides analytics storage)
3. **VPS 2** - Deploy last (depends on VPS 1 and VPS 3)

## Deployment Steps

### VPS 1: Ingress & Orchestration Layer

#### 1. Initial Setup
```bash
# SSH into VPS 1
ssh root@<VPS1_PUBLIC_IP>

# Update system
apt update && apt upgrade -y

# Clone repository
cd /opt
git clone https://github.com/yuran653/de_sandbox.git
cd de_sandbox
```

#### 2. Configure Environment
```bash
# Copy environment template
cd airflow_pg_s3
cp .env.example .env

# Edit .env file with appropriate values
nano .env
```

Required environment variables:
- `POSTGRES_USER`: Database username
- `POSTGRES_PASSWORD`: Database password
- `MINIO_ROOT_USER`: MinIO access key
- `MINIO_ROOT_PASSWORD`: MinIO secret key
- `HOST_IP`: Set to `10.104.0.2`

#### 3. Deploy Services
```bash
# Run deployment script
cd /opt/de_sandbox/deployment
./vps1-deploy.sh
```

#### 4. Verify Deployment
```bash
# Check running containers
docker ps

# Test Airflow web UI
curl http://10.104.0.2:8080

# Test MinIO
curl http://10.104.0.2:9000/minio/health/live
```

### VPS 2: Compute Layer

#### 1. Initial Setup
```bash
# SSH into VPS 2 from VPS 1 (via private network)
# First, SSH to VPS 1, then:
ssh root@10.104.0.3

# Update system
apt update && apt upgrade -y

# Clone repository
cd /opt
git clone https://github.com/yuran653/de_sandbox.git
cd de_sandbox
```

#### 2. Configure Environment
```bash
cd spark
cp .env.example .env

# Edit .env file
nano .env
```

Required environment variables:
- `HOST_IP`: Set to `10.104.0.3`
- `MASTER_PORT`: 7077
- `WEB_UI_PORT`: 8080
- `S3_ENDPOINT`: `http://10.104.0.2:9000`
- `S3_ACCESS_KEY`: Same as VPS 1 MinIO
- `S3_SECRET_KEY`: Same as VPS 1 MinIO

#### 3. Deploy Services
```bash
cd /opt/de_sandbox/deployment
./vps2-deploy.sh
```

#### 4. Verify Deployment
```bash
# Check running containers
docker ps

# Test Spark Master
curl http://10.104.0.3:8080

# Test connectivity to MinIO on VPS 1
curl http://10.104.0.2:9000/minio/health/live
```

### VPS 3: Analytics Layer

#### 1. Initial Setup
```bash
# SSH into VPS 3 from VPS 1 (via private network)
ssh root@10.104.0.4

# Update system
apt update && apt upgrade -y

# Clone repository
cd /opt
git clone https://github.com/yuran653/de_sandbox.git
cd de_sandbox
```

#### 2. Configure Environment
```bash
cd clickhouse
cp .env.example .env

# Edit .env file
nano .env
```

Required environment variables:
- `CH_HOST`: Set to `10.104.0.4`
- `CLICKHOUSE_USER`: Database username
- `CLICKHOUSE_PASSWORD`: Database password

#### 3. Deploy Services
```bash
cd /opt/de_sandbox/deployment
./vps3-deploy.sh
```

#### 4. Verify Deployment
```bash
# Check running containers
docker ps

# Test ClickHouse node 1
clickhouse-client --host 10.104.0.4 --port 9000 --query 'SELECT 1'

# Test ClickHouse node 2
clickhouse-client --host 10.104.0.4 --port 19000 --query 'SELECT 1'

# Test cluster
clickhouse-client --host 10.104.0.4 --port 9000 --query 'SELECT * FROM system.clusters'
```

## Post-Deployment Configuration

### Setup VPN Access (VPS 1)
```bash
# Install WireGuard
cd /opt/de_sandbox/airflow_pg_s3
./scripts/wireguard_install.sh

# Generate client configuration
cd /opt/de_sandbox/airflow_pg_s3/etc
./generate_client_config.sh client1

# Copy the generated config to your local machine
# File will be at: /etc/wireguard/client1.conf
```

### Configure Airflow Connections

1. Access Airflow UI via VPN: `http://10.104.0.2:8080`
2. Navigate to Admin → Connections
3. Add Spark connection:
   - Connection Id: `spark_default`
   - Connection Type: `Spark`
   - Host: `10.104.0.3`
   - Port: `7077`

4. Add ClickHouse connection:
   - Connection Id: `clickhouse_default`
   - Connection Type: `Generic`
   - Host: `10.104.0.4`
   - Port: `9000`
   - Login: (from VPS 3 .env)
   - Password: (from VPS 3 .env)

### Test End-to-End Data Pipeline

1. Create a test DAG that:
   - Reads data from MinIO (VPS 1)
   - Processes with Spark (VPS 2)
   - Writes to ClickHouse (VPS 3)

2. Monitor execution in Airflow UI

## Security Checklist

- [ ] VPS 1 firewall configured (only necessary ports open)
- [ ] VPS 2 and VPS 3 have NO public IP addresses
- [ ] WireGuard VPN is configured and tested
- [ ] All services use strong passwords
- [ ] SSH key authentication enabled (password auth disabled)
- [ ] Regular security updates scheduled
- [ ] SSL/TLS configured for web UIs (optional but recommended)

## Monitoring and Maintenance

### Health Checks
```bash
# VPS 1
docker ps
docker compose -f /opt/de_sandbox/airflow_pg_s3/docker-compose.yaml ps

# VPS 2
docker ps
docker compose -f /opt/de_sandbox/spark/docker-compose.yaml ps

# VPS 3
docker ps
docker compose -f /opt/de_sandbox/clickhouse/docker-compose.yaml ps
```

### Logs
```bash
# View logs for specific service
docker compose logs -f <service_name>

# View all logs
docker compose logs -f
```

### Backups
Important directories to backup:
- VPS 1: `/airflow/*`, `/pg_*`, `/minio_datalake`
- VPS 2: `/spark_events`
- VPS 3: `/clickhouse/*`

## Troubleshooting

### Cannot connect to services
- Verify VPC configuration
- Check firewall rules
- Ensure services are running: `docker ps`
- Check service logs: `docker compose logs <service>`

### Spark cannot connect to MinIO
- Verify S3 credentials in Spark configuration
- Test connectivity: `curl http://10.104.0.2:9000/minio/health/live` from VPS 2
- Check network routing

### ClickHouse cluster not forming
- Verify Zookeeper is running and healthy
- Check ClickHouse logs
- Ensure both nodes can reach Zookeeper
- Verify cluster configuration in `/etc/clickhouse-server/config.d/`

### Airflow cannot trigger Spark jobs
- Verify Spark connection in Airflow
- Check Spark Master is accessible: `curl http://10.104.0.3:8080`
- Review Airflow logs
- Verify network connectivity between VPS 1 and VPS 2

## Service Access URLs

When connected via VPN:

- **Airflow UI**: http://10.104.0.2:8080
- **MinIO Console**: http://10.104.0.2:9001
- **Spark Master UI**: http://10.104.0.3:8080
- **Spark Worker 1 UI**: http://10.104.0.3:8081
- **Spark Worker 2 UI**: http://10.104.0.3:8082
- **Spark History Server**: http://10.104.0.3:18080
- **Jupyter Notebook**: http://10.104.0.3:8888
- **ClickHouse Node 1**: TCP 10.104.0.4:9000, HTTP 10.104.0.4:8123
- **ClickHouse Node 2**: TCP 10.104.0.4:19000, HTTP 10.104.0.4:18123

## Support and Documentation

For issues and questions:
- Review CONFIGURATION.md for architecture details
- Check PLAN.md for implementation details
- Consult component-specific documentation in respective directories
