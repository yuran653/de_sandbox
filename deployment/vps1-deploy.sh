#!/bin/bash

# VPS 1 Deployment Script - Ingress & Orchestration Layer
# Deploy: Airflow, PostgreSQL (Metadata + OLTP), MinIO
# Network: 10.104.0.2 (Private) + Public IP
# Role: Single entry point, orchestration, storage

set -euo pipefail

# Color codes for terminal output
BLUE='\033[1;34m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}VPS 1 Deployment Script${NC}"
echo -e "${BLUE}Ingress & Orchestration Layer${NC}"
echo -e "${BLUE}========================================${NC}"

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Please run as root (use sudo)${NC}"
    exit 1
fi

# Verify we're on the correct IP
CURRENT_IP=$(ip -4 addr show | grep 'inet.*10.104.0' | awk '{print $2}' | cut -d'/' -f1 | head -1)
EXPECTED_IP="10.104.0.2"

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
echo -e "\n${YELLOW}Step 1/6: System Preparation${NC}"
echo -e "Creating required directories..."

# Create directory structure
mkdir -p /airflow/dags
mkdir -p /airflow/logs
mkdir -p /airflow/plugins
mkdir -p /airflow/scripts
mkdir -p /spark_events
mkdir -p /pg_metadata
mkdir -p /pg_datalake
mkdir -p /minio_datalake

# Set proper permissions
chmod -R 755 /airflow
chmod -R 755 /spark_events
chmod -R 700 /pg_metadata
chmod -R 700 /pg_datalake
chmod -R 755 /minio_datalake

echo -e "${GREEN}Directories created successfully${NC}"

# Step 2: Install Docker
echo -e "\n${YELLOW}Step 2/6: Installing Docker${NC}"
if command -v docker &> /dev/null; then
    echo -e "${GREEN}Docker already installed, version: $(docker --version)${NC}"
else
    echo -e "Installing Docker..."
    cd /opt/de_sandbox/airflow_pg_s3
    if [ -f "./scripts/docker_install.sh" ]; then
        bash "./scripts/docker_install.sh"
        echo -e "${GREEN}Docker installation completed${NC}"
    else
        echo -e "${RED}Error: docker_install.sh not found${NC}"
        exit 1
    fi
fi

# Step 3: Install WireGuard VPN
echo -e "\n${YELLOW}Step 3/6: Installing WireGuard VPN${NC}"
if command -v wg &> /dev/null; then
    echo -e "${GREEN}WireGuard already installed${NC}"
else
    echo -e "Installing WireGuard..."
    cd /opt/de_sandbox/airflow_pg_s3
    if [ -f "./scripts/wireguard_install.sh" ]; then
        bash "./scripts/wireguard_install.sh"
        echo -e "${GREEN}WireGuard installation completed${NC}"
    else
        echo -e "${YELLOW}Warning: wireguard_install.sh not found, skipping VPN setup${NC}"
    fi
fi

# Step 4: Configure Environment
echo -e "\n${YELLOW}Step 4/6: Configuring Environment${NC}"

cd /opt/de_sandbox/airflow_pg_s3

# Check if .env exists
if [ ! -f ".env" ]; then
    echo -e "${RED}Error: .env file not found${NC}"
    echo -e "${YELLOW}Please create .env file with required variables${NC}"
    echo -e "Required variables:"
    echo -e "  - POSTGRES_USER"
    echo -e "  - POSTGRES_PASSWORD"
    echo -e "  - MINIO_ROOT_USER"
    echo -e "  - MINIO_ROOT_PASSWORD"
    exit 1
fi

# Verify critical environment variables
source .env
if [ -z "${POSTGRES_USER:-}" ] || [ -z "${POSTGRES_PASSWORD:-}" ]; then
    echo -e "${RED}Error: PostgreSQL credentials not set in .env${NC}"
    exit 1
fi

if [ -z "${MINIO_ROOT_USER:-}" ] || [ -z "${MINIO_ROOT_PASSWORD:-}" ]; then
    echo -e "${RED}Error: MinIO credentials not set in .env${NC}"
    exit 1
fi

echo -e "${GREEN}Environment configuration verified${NC}"

# Step 5: Build and Deploy Airflow Stack
echo -e "\n${YELLOW}Step 5/6: Building and Deploying Airflow Stack${NC}"

cd /opt/de_sandbox/airflow_pg_s3

echo -e "Building custom Airflow image..."
docker compose build

echo -e "Starting services..."
docker compose up -d

# Wait for services to be healthy
echo -e "\n${YELLOW}Waiting for services to become healthy...${NC}"
sleep 10

# Check service health
echo -e "\n${YELLOW}Checking service health...${NC}"
docker compose ps

# Step 6: Firewall Configuration
echo -e "\n${YELLOW}Step 6/6: Configuring Firewall${NC}"

# Check if nftables is available
if command -v nft &> /dev/null; then
    echo -e "Configuring nftables firewall rules..."
    
    # Basic firewall rules for VPS 1
    # Allow SSH, WireGuard VPN, and Airflow UI
    cat > /tmp/nftables-vps1.conf << 'EOF'
#!/usr/sbin/nft -f

flush ruleset

table inet filter {
    chain input {
        type filter hook input priority 0; policy drop;
        
        # Allow established connections
        ct state established,related accept
        
        # Allow loopback
        iif lo accept
        
        # Allow SSH
        tcp dport 22 accept
        
        # Allow WireGuard
        udp dport 51820 accept
        
        # Allow ping
        icmp type echo-request accept
        icmpv6 type echo-request accept
        
        # Allow private network
        ip saddr 10.104.0.0/24 accept
        
        # Log dropped packets
        log prefix "nft-dropped: " drop
    }
    
    chain forward {
        type filter hook forward priority 0; policy accept;
    }
    
    chain output {
        type filter hook output priority 0; policy accept;
    }
}
EOF
    
    # Apply firewall rules (optional - commented out for safety)
    # chmod +x /tmp/nftables-vps1.conf
    # /tmp/nftables-vps1.conf
    
    echo -e "${YELLOW}Firewall rules prepared at /tmp/nftables-vps1.conf${NC}"
    echo -e "${YELLOW}Review and apply manually if needed: nft -f /tmp/nftables-vps1.conf${NC}"
else
    echo -e "${YELLOW}nftables not found, skipping firewall configuration${NC}"
fi

# Final verification
echo -e "\n${BLUE}========================================${NC}"
echo -e "${GREEN}VPS 1 Deployment Completed!${NC}"
echo -e "${BLUE}========================================${NC}"

echo -e "\n${YELLOW}Service Status:${NC}"
docker compose -f /opt/de_sandbox/airflow_pg_s3/docker-compose.yaml ps

echo -e "\n${YELLOW}Access Information:${NC}"
echo -e "Airflow Web UI: http://10.104.0.2:8080"
echo -e "MinIO Console: http://10.104.0.2:9001"
echo -e "PostgreSQL Metadata: 10.104.0.2:5433"
echo -e "PostgreSQL Datalake: 10.104.0.2:5432"
echo -e "MinIO S3 API: http://10.104.0.2:9000"

echo -e "\n${YELLOW}Next Steps:${NC}"
echo -e "1. Configure WireGuard VPN clients (if not already done)"
echo -e "2. Test connectivity to all services"
echo -e "3. Proceed with VPS 3 deployment (ClickHouse)"
echo -e "4. Then proceed with VPS 2 deployment (Spark)"

echo -e "\n${GREEN}For detailed logs, use: docker compose logs -f${NC}"
