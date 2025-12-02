#!/bin/bash

# Master Installation Script for Debian 12
# This script orchestrates the complete setup process by running:
# 1. Docker and Docker Compose installation
# 2. Routing setup
# 3. ClickHouse initialization and deployment

set -euo pipefail

# Color codes for terminal output
BLUE='\033[1;34m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Starting Complete Installation Process${NC}"
echo -e "${BLUE}========================================${NC}"

# Install Docker and Docker Compose
echo -e "\n${YELLOW}Step 1/3: Installing Docker and Docker Compose${NC}"
if [ -f "./scripts/docker_install.sh" ]; then
    bash "./scripts/docker_install.sh"
    echo -e "${GREEN}Docker installation completed${NC}"
else
    echo -e "${RED}Error: docker_install.sh not found${NC}"
    exit 1
fi

# Setup routing
echo -e "\n${YELLOW}Step 2/3: Setting up routing${NC}"
if [ -f "./scripts/setup_routing.sh" ]; then
    bash "./scripts/setup_routing.sh"
    echo -e "${GREEN}Routing setup completed${NC}"
else
    echo -e "${RED}Error: setup_routing.sh not found${NC}"
    exit 1
fi

# Initialize and deploy ClickHouse cluster
echo -e "\n${YELLOW}Step 3/3: Initializing and deploying ClickHouse${NC}"
if [ -f "./docker-compose.yaml" ]; then
    mkdir -p /clickhouse/01/data /clickhouse/01/logs /clickhouse/02/data /clickhouse/02/logs /clickhouse/zk/data /clickhouse/zk/logs
    docker compose up -d --build
    echo -e "${GREEN} ClickHouse deployment completed${NC}"
else
    echo -e "${RED}Error: docker-compose.yaml not found${NC}"
    exit 1
fi

echo -e "\n${BLUE}========================================${NC}"
echo -e "${GREEN}All installation steps completed successfully!${NC}"
echo -e "${BLUE}========================================${NC}"
