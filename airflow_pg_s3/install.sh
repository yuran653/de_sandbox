#!/bin/bash

# Master Installation Script for Debian 12
# This script orchestrates the complete setup process by running:
# 1. WireGuard VPN configuration
# 2. Docker and Docker Compose installation
# 3. Airflow initialization and deployment

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

# Step 1: Install WireGuard
echo -e "\n${YELLOW}Step 1/3: Installing and configuring WireGuard VPN${NC}"
if [ -f "./scripts/wireguard_install.sh" ]; then
    bash "./scripts/wireguard_install.sh"
    echo -e "${GREEN}WireGuard installation completed${NC}"
else
    echo -e "${RED}Error: wireguard_install.sh not found${NC}"
    exit 1
fi

# Step 2: Install Docker
echo -e "\n${YELLOW}Step 2/3: Installing Docker and Docker Compose${NC}"
if [ -f "./scripts/docker_install.sh" ]; then
    bash "./scripts/docker_install.sh"
    echo -e "${GREEN}Docker installation completed${NC}"
else
    echo -e "${RED}Error: docker_install.sh not found${NC}"
    exit 1
fi

# Step 3: Initialize and deploy Airflow
echo -e "\n${YELLOW}Step 3/3: Initializing and deploying Airflow${NC}"
if [ -f "./scripts/airflow_init_deploy.sh" ]; then
    bash "./scripts/airflow_init_deploy.sh"
    echo -e "${GREEN}Airflow deployment completed${NC}"
else
    echo -e "${RED}Error: airflow_init_deploy.sh not found${NC}"
    exit 1
fi

echo -e "\n${BLUE}========================================${NC}"
echo -e "${GREEN}All installation steps completed successfully!${NC}"
echo -e "${BLUE}========================================${NC}"
