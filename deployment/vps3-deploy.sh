#!/bin/bash

# VPS 3 Deployment Script - Analytics Layer
# Deploy: ClickHouse Cluster (2 nodes), Zookeeper
# Network: 10.104.0.4 (Private only, no public IP)
# Role: OLAP storage and query processing

set -euo pipefail

# Color codes for terminal output
BLUE='\033[1;34m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}VPS 3 Deployment Script${NC}"
echo -e "${BLUE}Analytics Layer${NC}"
echo -e "${BLUE}========================================${NC}"

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Please run as root (use sudo)${NC}"
    exit 1
fi

# Verify we're on the correct IP
CURRENT_IP=$(ip -4 addr show | grep 'inet.*10.104.0' | awk '{print $2}' | cut -d'/' -f1 | head -1)
EXPECTED_IP="10.104.0.4"

echo -e "\n${YELLOW}Verifying network configuration...${NC}"
echo -e "Current private IP: ${CURRENT_IP}"
echo -e "Expected IP: ${EXPECTED_IP}"

if [ "$CURRENT_IP" != "$EXPECTED_IP" ]; then
    echo -e "${RED}Warning: Private IP mismatch!${NC}"
    echo -e "${YELLOW}Expected: ${EXPECTED_IP}, Found: ${CURRENT_IP}${NC}"
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Step 1: System Preparation
echo -e "\n${YELLOW}Step 1/4: System Preparation${NC}"
echo -e "Creating required directories..."

# Create directory structure
mkdir -p /clickhouse/zk/data
mkdir -p /clickhouse/zk/logs
mkdir -p /clickhouse/01/data
mkdir -p /clickhouse/01/logs
mkdir -p /clickhouse/02/data
mkdir -p /clickhouse/02/logs

# Set proper permissions
chmod -R 755 /clickhouse

echo -e "${GREEN}Directories created successfully${NC}"

# Step 2: Install Docker
echo -e "\n${YELLOW}Step 2/4: Installing Docker${NC}"
if command -v docker &> /dev/null; then
    echo -e "${GREEN}Docker already installed, version: $(docker --version)${NC}"
else
    echo -e "Installing Docker..."
    cd /opt/de_sandbox/clickhouse
    if [ -f "./scripts/docker_install.sh" ]; then
        bash "./scripts/docker_install.sh"
        echo -e "${GREEN}Docker installation completed${NC}"
    else
        echo -e "${RED}Error: docker_install.sh not found${NC}"
        exit 1
    fi
fi

# Step 3: Configure Environment
echo -e "\n${YELLOW}Step 3/4: Configuring Environment${NC}"

cd /opt/de_sandbox/clickhouse

# Check if .env exists
if [ ! -f ".env" ]; then
    echo -e "${RED}Error: .env file not found${NC}"
    echo -e "${YELLOW}Please create .env file with required variables${NC}"
    echo -e "Required variables:"
    echo -e "  - CH_HOST=10.104.0.4"
    exit 1
fi

# Verify critical environment variables
source .env
if [ -z "${CH_HOST:-}" ]; then
    echo -e "${RED}Error: CH_HOST not set in .env${NC}"
    exit 1
fi

if [ "${CH_HOST}" != "10.104.0.4" ]; then
    echo -e "${YELLOW}Warning: CH_HOST in .env is ${CH_HOST}, expected 10.104.0.4${NC}"
fi

echo -e "${GREEN}Environment configuration verified${NC}"

# Step 4: Build and Deploy ClickHouse Cluster
echo -e "\n${YELLOW}Step 4/4: Building and Deploying ClickHouse Cluster${NC}"

cd /opt/de_sandbox/clickhouse

echo -e "Building custom images..."
docker compose build

echo -e "Starting services..."
docker compose up -d

# Wait for services to be healthy
echo -e "\n${YELLOW}Waiting for services to become healthy...${NC}"
sleep 20

# Check service health
echo -e "\n${YELLOW}Checking service health...${NC}"
docker compose ps

# Verify ClickHouse nodes are accessible
echo -e "\n${YELLOW}Verifying ClickHouse nodes...${NC}"

# Check if clickhouse-client is available in container
if docker exec clickhouse-01 clickhouse-client --port 9000 --query 'SELECT 1' &> /dev/null; then
    echo -e "${GREEN}✓ ClickHouse Node 1 is responding${NC}"
else
    echo -e "${YELLOW}⚠ ClickHouse Node 1 may not be ready yet${NC}"
fi

if docker exec clickhouse-02 clickhouse-client --port 19000 --query 'SELECT 1' &> /dev/null; then
    echo -e "${GREEN}✓ ClickHouse Node 2 is responding${NC}"
else
    echo -e "${YELLOW}⚠ ClickHouse Node 2 may not be ready yet${NC}"
fi

# Check cluster status
echo -e "\n${YELLOW}Checking cluster configuration...${NC}"
if docker exec clickhouse-01 clickhouse-client --port 9000 --query 'SELECT * FROM system.clusters' &> /dev/null; then
    echo -e "${GREEN}✓ Cluster configuration loaded${NC}"
    docker exec clickhouse-01 clickhouse-client --port 9000 --query 'SELECT cluster, shard_num, replica_num, host_name FROM system.clusters WHERE cluster = '\''ch_cluster'\'''
else
    echo -e "${YELLOW}⚠ Cluster may not be fully configured yet${NC}"
fi

# Verify database creation
echo -e "\n${YELLOW}Verifying ch_datalake database...${NC}"
if docker exec clickhouse-01 clickhouse-client --port 9000 --query 'SHOW DATABASES' | grep -q 'ch_datalake'; then
    echo -e "${GREEN}✓ ch_datalake database exists${NC}"
else
    echo -e "${YELLOW}⚠ ch_datalake database may not be created yet${NC}"
fi

# Final verification
echo -e "\n${BLUE}========================================${NC}"
echo -e "${GREEN}VPS 3 Deployment Completed!${NC}"
echo -e "${BLUE}========================================${NC}"

echo -e "\n${YELLOW}Service Status:${NC}"
docker compose -f /opt/de_sandbox/clickhouse/docker-compose.yaml ps

echo -e "\n${YELLOW}Access Information (via VPN from VPS 1):${NC}"
echo -e "ClickHouse Node 1 (TCP): 10.104.0.4:9000"
echo -e "ClickHouse Node 1 (HTTP): http://10.104.0.4:8123"
echo -e "ClickHouse Node 2 (TCP): 10.104.0.4:19000"
echo -e "ClickHouse Node 2 (HTTP): http://10.104.0.4:18123"
echo -e "Zookeeper: 10.104.0.4:2181"

echo -e "\n${YELLOW}Test Commands:${NC}"
echo -e "# Connect to node 1:"
echo -e "docker exec -it clickhouse-01 clickhouse-client --port 9000"
echo -e ""
echo -e "# Connect to node 2:"
echo -e "docker exec -it clickhouse-02 clickhouse-client --port 19000"
echo -e ""
echo -e "# Check cluster status:"
echo -e "docker exec clickhouse-01 clickhouse-client --port 9000 --query 'SELECT * FROM system.clusters'"

echo -e "\n${YELLOW}Next Steps:${NC}"
echo -e "1. Configure Spark on VPS 2 to write to ClickHouse"
echo -e "2. Configure Airflow on VPS 1 to query ClickHouse"
echo -e "3. Create distributed tables for data ingestion"
echo -e "4. Test end-to-end data pipeline"

echo -e "\n${GREEN}For detailed logs, use: docker compose logs -f${NC}"
