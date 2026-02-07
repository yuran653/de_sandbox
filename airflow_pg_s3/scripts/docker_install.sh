#!/bin/bash

# Docker and Docker Compose Installation Script
# This script installs a specific version of
# Docker Engine and Docker Compose on Debian 12
# It handles repository setup, package install,
# service enablement, and user configuration

set -euo pipefail

# Ensure script runs from project root
# for consistent relative paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${SCRIPT_DIR}/.."
cd "${PROJECT_ROOT}"

BLUE='\033[1;34m'
GREEN='\033[0;32m'
NC='\033[0m'

DOCKER_VERSION="26.0.2"
COMPOSE_VERSION="2.25.0"

DEBIAN_CODENAME=$(lsb_release -cs)

echo -e "${BLUE}Installing Docker ${DOCKER_VERSION}"
echo -e "and Compose ${COMPOSE_VERSION}${NC}"

echo -e "${BLUE}Updating system packages${NC}"
apt update && apt upgrade -y

echo -e "${BLUE}Installing prerequisites${NC}"
apt install -y ca-certificates curl gnupg \
    lsb-release tree rsync postgresql-client \
    netcat-openbsd

echo -e "${BLUE}Adding Docker GPG key${NC}"
install -m 0755 -d /etc/apt/keyrings
curl -fsSL \
    https://download.docker.com/linux/debian/gpg | \
    gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

echo -e "${BLUE}Adding Docker repository${NC}"
echo \
"deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/debian $(lsb_release -cs) stable" | \
tee /etc/apt/sources.list.d/docker.list > /dev/null

echo -e "${BLUE}Updating package index${NC}"
apt update

echo -e "${BLUE}Installing Docker Engine"
echo -e "v${DOCKER_VERSION} and Compose"
echo -e "v${COMPOSE_VERSION}${NC}"
FULL_DOCKER="5:${DOCKER_VERSION}-1~debian.12~${DEBIAN_CODENAME}"
FULL_COMPOSE="${COMPOSE_VERSION}-1~debian.12~${DEBIAN_CODENAME}"

apt install -y \
    docker-ce=${FULL_DOCKER} \
    docker-ce-cli=${FULL_DOCKER} \
    containerd.io \
    docker-buildx-plugin \
    docker-compose-plugin=${FULL_COMPOSE}

echo -e "${BLUE}Holding Docker packages"
echo -e "at current versions${NC}"
apt-mark hold docker-ce docker-ce-cli docker-compose-plugin

echo -e "${BLUE}Adding current user to docker group${NC}"
usermod -aG docker $USER

echo -e "${BLUE}Enabling and starting Docker service${NC}"
systemctl enable --now docker

echo -e "${BLUE}Checking Docker service status${NC}"
systemctl status docker --no-pager

echo -e "${BLUE}Verifying installation${NC}"
docker --version
docker compose version

echo -e "${GREEN}Docker installation complete${NC}"

# Upload command:
# scp <PATH>/docker_install.sh root@<IP_ADDRESS>:~/<PATH>
