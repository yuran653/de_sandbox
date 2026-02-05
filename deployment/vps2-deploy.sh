#!/bin/bash

# VPS 2 Deployment Script - Compute Layer
# Deploy: Spark Cluster (Master + Workers), Jupyter Notebook
# Network: 10.104.0.3 (Private only, no public IP)
# Role: Distributed data processing

set -euo pipefail

# Color codes for terminal output
BLUE='\033[1;34m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}VPS 2 Deployment Script${NC}"
echo -e "${BLUE}Compute Layer${NC}"
echo -e "${BLUE}========================================${NC}"

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Please run as root (use sudo)${NC}"
    exit 1
fi

# Verify we're on the correct IP
CURRENT_IP=$(ip -4 addr show | grep 'inet.*10.104.0' | awk '{print $2}' | cut -d'/' -f1 | head -1)
EXPECTED_IP="10.104.0.3"

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
echo -e "\n${YELLOW}Step 1/5: System Preparation${NC}"
echo -e "Creating required directories..."

# Create directory structure
mkdir -p /spark_events

# Set proper permissions
chmod -R 755 /spark_events

echo -e "${GREEN}Directories created successfully${NC}"

# Step 2: Verify connectivity to VPS 1
echo -e "\n${YELLOW}Step 2/5: Verifying connectivity to VPS 1${NC}"

VPS1_IP="10.104.0.2"
echo -e "Testing connection to VPS 1 (${VPS1_IP})..."

# Test MinIO connectivity
if curl -f -s -o /dev/null -m 5 "http://${VPS1_IP}:9000/minio/health/live"; then
    echo -e "${GREEN}✓ MinIO is reachable on VPS 1${NC}"
else
    echo -e "${RED}✗ Cannot reach MinIO on VPS 1${NC}"
    echo -e "${YELLOW}Please ensure VPS 1 is deployed and running${NC}"
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Step 3: Install Docker
echo -e "\n${YELLOW}Step 3/5: Installing Docker${NC}"
if command -v docker &> /dev/null; then
    echo -e "${GREEN}Docker already installed, version: $(docker --version)${NC}"
else
    echo -e "Installing Docker..."
    cd /opt/de_sandbox/spark
    if [ -f "./scripts/docker_install.sh" ]; then
        bash "./scripts/docker_install.sh"
        echo -e "${GREEN}Docker installation completed${NC}"
    else
        echo -e "${RED}Error: docker_install.sh not found${NC}"
        exit 1
    fi
fi

# Step 4: Configure Environment
echo -e "\n${YELLOW}Step 4/5: Configuring Environment${NC}"

cd /opt/de_sandbox/spark

# Check if .env exists
if [ ! -f ".env" ]; then
    echo -e "${RED}Error: .env file not found${NC}"
    echo -e "${YELLOW}Please create .env file with required variables${NC}"
    echo -e "Required variables:"
    echo -e "  - HOST_IP=10.104.0.3"
    echo -e "  - MASTER_PORT=7077"
    echo -e "  - WEB_UI_PORT=8080"
    exit 1
fi

# Verify critical environment variables
source .env
if [ -z "${HOST_IP:-}" ]; then
    echo -e "${RED}Error: HOST_IP not set in .env${NC}"
    exit 1
fi

if [ "${HOST_IP}" != "10.104.0.3" ]; then
    echo -e "${YELLOW}Warning: HOST_IP in .env is ${HOST_IP}, expected 10.104.0.3${NC}"
fi

echo -e "${GREEN}Environment configuration verified${NC}"

# Step 5: Build and Deploy Spark Cluster
echo -e "\n${YELLOW}Step 5/5: Building and Deploying Spark Cluster${NC}"

cd /opt/de_sandbox/spark

echo -e "Building custom Spark image..."
docker compose build

echo -e "Starting services..."
docker compose up -d

# Wait for services to be healthy
echo -e "\n${YELLOW}Waiting for services to become healthy...${NC}"
sleep 15

# Check service health
echo -e "\n${YELLOW}Checking service health...${NC}"
docker compose ps

# Verify Spark Master is accessible
echo -e "\n${YELLOW}Verifying Spark Master...${NC}"
if curl -f -s -o /dev/null -m 5 "http://10.104.0.3:8080"; then
    echo -e "${GREEN}✓ Spark Master UI is accessible${NC}"
else
    echo -e "${YELLOW}⚠ Spark Master UI may not be ready yet${NC}"
fi

# Final verification
echo -e "\n${BLUE}========================================${NC}"
echo -e "${GREEN}VPS 2 Deployment Completed!${NC}"
echo -e "${BLUE}========================================${NC}"

echo -e "\n${YELLOW}Service Status:${NC}"
docker compose -f /opt/de_sandbox/spark/docker-compose.yaml ps

echo -e "\n${YELLOW}Access Information (via VPN from VPS 1):${NC}"
echo -e "Spark Master UI: http://10.104.0.3:8080"
echo -e "Spark Worker 1 UI: http://10.104.0.3:8081"
echo -e "Spark Worker 2 UI: http://10.104.0.3:8082"
echo -e "Spark History Server: http://10.104.0.3:18080"
echo -e "Jupyter Notebook: http://10.104.0.3:8888"
echo -e "Spark Master URL: spark://10.104.0.3:7077"

echo -e "\n${YELLOW}Connectivity Test:${NC}"
echo -e "MinIO (VPS 1): http://10.104.0.2:9000"

echo -e "\n${YELLOW}Next Steps:${NC}"
echo -e "1. Configure Airflow on VPS 1 to connect to Spark"
echo -e "2. Test Spark job submission from Airflow"
echo -e "3. Verify Spark can read/write to MinIO on VPS 1"
echo -e "4. Test Spark writing to ClickHouse on VPS 3"

echo -e "\n${GREEN}For detailed logs, use: docker compose logs -f${NC}"
