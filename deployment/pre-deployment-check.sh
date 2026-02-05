#!/bin/bash

# Pre-deployment Check Script
# Run this script before deploying to verify prerequisites and configuration

set -euo pipefail

# Color codes for terminal output
BLUE='\033[1;34m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

CHECKS_PASSED=0
CHECKS_FAILED=0
WARNINGS=0

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}DE Sandbox Pre-Deployment Check${NC}"
echo -e "${BLUE}========================================${NC}"

# Function to print check result
check_pass() {
    echo -e "${GREEN}✓${NC} $1"
    ((CHECKS_PASSED++))
}

check_fail() {
    echo -e "${RED}✗${NC} $1"
    ((CHECKS_FAILED++))
}

check_warn() {
    echo -e "${YELLOW}⚠${NC} $1"
    ((WARNINGS++))
}

# Check 1: Root privileges
echo -e "\n${YELLOW}Checking system requirements...${NC}"
if [ "$EUID" -eq 0 ]; then
    check_pass "Running as root"
else
    check_warn "Not running as root - some checks may be skipped"
fi

# Check 2: Operating System
if [ -f /etc/os-release ]; then
    . /etc/os-release
    if [[ "$ID" == "debian" ]] && [[ "$VERSION_ID" == "12" ]]; then
        check_pass "Debian 12 detected"
    else
        check_warn "Not Debian 12 (detected: $ID $VERSION_ID) - may encounter issues"
    fi
else
    check_fail "Cannot detect operating system"
fi

# Check 3: Available disk space
echo -e "\n${YELLOW}Checking available resources...${NC}"
REQUIRED_SPACE_GB=50
AVAILABLE_SPACE_GB=$(df / | tail -1 | awk '{print int($4/1024/1024)}')
if [ "$AVAILABLE_SPACE_GB" -ge "$REQUIRED_SPACE_GB" ]; then
    check_pass "Sufficient disk space: ${AVAILABLE_SPACE_GB}GB available (required: ${REQUIRED_SPACE_GB}GB)"
else
    check_fail "Insufficient disk space: ${AVAILABLE_SPACE_GB}GB available (required: ${REQUIRED_SPACE_GB}GB)"
fi

# Check 4: Available memory
REQUIRED_MEMORY_GB=8
AVAILABLE_MEMORY_GB=$(free -g | awk '/^Mem:/{print $2}')
if [ "$AVAILABLE_MEMORY_GB" -ge "$REQUIRED_MEMORY_GB" ]; then
    check_pass "Sufficient memory: ${AVAILABLE_MEMORY_GB}GB available (required: ${REQUIRED_MEMORY_GB}GB)"
else
    check_warn "Low memory: ${AVAILABLE_MEMORY_GB}GB available (recommended: ${REQUIRED_MEMORY_GB}GB)"
fi

# Check 5: Network connectivity
echo -e "\n${YELLOW}Checking network connectivity...${NC}"
if ping -c 1 -W 2 8.8.8.8 &> /dev/null; then
    check_pass "Internet connectivity available"
else
    check_fail "No internet connectivity - required for Docker image pulls"
fi

# Check 6: Private network configuration
echo -e "\n${YELLOW}Checking network configuration...${NC}"
PRIVATE_IP=$(ip -4 addr show | grep 'inet.*10.104.0' | awk '{print $2}' | cut -d'/' -f1 | head -1)
if [[ $PRIVATE_IP =~ ^10\.104\.0\.[2-4]$ ]]; then
    check_pass "Valid private IP detected: $PRIVATE_IP"
    
    # Determine which VPS this is
    if [ "$PRIVATE_IP" == "10.104.0.2" ]; then
        echo -e "  ${BLUE}→${NC} This appears to be VPS 1 (Ingress & Orchestration)"
        VPS_TYPE="vps1"
    elif [ "$PRIVATE_IP" == "10.104.0.3" ]; then
        echo -e "  ${BLUE}→${NC} This appears to be VPS 2 (Compute Layer)"
        VPS_TYPE="vps2"
    elif [ "$PRIVATE_IP" == "10.104.0.4" ]; then
        echo -e "  ${BLUE}→${NC} This appears to be VPS 3 (Analytics Layer)"
        VPS_TYPE="vps3"
    fi
else
    check_warn "Private IP ($PRIVATE_IP) not in expected range (10.104.0.2-4)"
    echo -e "  ${YELLOW}→${NC} For single-host deployment, this is OK"
    echo -e "  ${YELLOW}→${NC} For multi-VPS deployment, ensure VPC is configured correctly"
fi

# Check 7: Required directories
echo -e "\n${YELLOW}Checking directory structure...${NC}"
if [ -d "/opt/de_sandbox" ]; then
    check_pass "Repository found at /opt/de_sandbox"
else
    check_warn "Repository not at /opt/de_sandbox - assuming current directory"
fi

# Check 8: Environment files
echo -e "\n${YELLOW}Checking environment configuration...${NC}"
if [ -n "${VPS_TYPE:-}" ]; then
    case $VPS_TYPE in
        vps1)
            if [ -f "/opt/de_sandbox/airflow_pg_s3/.env" ]; then
                check_pass "Environment file exists for VPS 1"
            else
                check_fail "Missing .env file: /opt/de_sandbox/airflow_pg_s3/.env"
                echo -e "  ${YELLOW}→${NC} Copy from deployment/vps1.env.template"
            fi
            ;;
        vps2)
            if [ -f "/opt/de_sandbox/spark/.env" ]; then
                check_pass "Environment file exists for VPS 2"
            else
                check_fail "Missing .env file: /opt/de_sandbox/spark/.env"
                echo -e "  ${YELLOW}→${NC} Copy from deployment/vps2.env.template"
            fi
            ;;
        vps3)
            if [ -f "/opt/de_sandbox/clickhouse/.env" ]; then
                check_pass "Environment file exists for VPS 3"
            else
                check_fail "Missing .env file: /opt/de_sandbox/clickhouse/.env"
                echo -e "  ${YELLOW}→${NC} Copy from deployment/vps3.env.template"
            fi
            ;;
    esac
fi

# Check 9: Docker installation
echo -e "\n${YELLOW}Checking Docker...${NC}"
if command -v docker &> /dev/null; then
    check_pass "Docker is installed: $(docker --version)"
    
    # Check if Docker daemon is running
    if docker info &> /dev/null; then
        check_pass "Docker daemon is running"
    else
        check_fail "Docker daemon is not running"
    fi
else
    check_warn "Docker not installed - will be installed during deployment"
fi

# Check 10: Docker Compose installation
if command -v docker &> /dev/null; then
    if docker compose version &> /dev/null; then
        check_pass "Docker Compose is available: $(docker compose version --short)"
    else
        check_warn "Docker Compose not available - will be installed during deployment"
    fi
fi

# Check 11: Port availability (if Docker is installed)
if command -v docker &> /dev/null && docker info &> /dev/null; then
    echo -e "\n${YELLOW}Checking port availability...${NC}"
    REQUIRED_PORTS=""
    
    case ${VPS_TYPE:-} in
        vps1)
            REQUIRED_PORTS="8080 9000 9001 5432 5433"
            ;;
        vps2)
            REQUIRED_PORTS="7077 8080 8081 8082 8888 18080"
            ;;
        vps3)
            REQUIRED_PORTS="9000 8123 19000 18123 2181"
            ;;
    esac
    
    if [ -n "$REQUIRED_PORTS" ]; then
        for port in $REQUIRED_PORTS; do
            if ss -tulpn 2>/dev/null | grep -q ":$port "; then
                check_fail "Port $port is already in use"
            else
                check_pass "Port $port is available"
            fi
        done
    fi
fi

# Summary
echo -e "\n${BLUE}========================================${NC}"
echo -e "${BLUE}Pre-Deployment Check Summary${NC}"
echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}Passed:${NC} $CHECKS_PASSED"
echo -e "${YELLOW}Warnings:${NC} $WARNINGS"
echo -e "${RED}Failed:${NC} $CHECKS_FAILED"

if [ $CHECKS_FAILED -eq 0 ]; then
    echo -e "\n${GREEN}✓ System is ready for deployment!${NC}"
    echo -e "\nNext steps:"
    if [ -n "${VPS_TYPE:-}" ]; then
        echo -e "  1. Review /opt/de_sandbox/deployment/README.md"
        echo -e "  2. Run: /opt/de_sandbox/deployment/${VPS_TYPE}-deploy.sh"
    else
        echo -e "  1. For multi-VPS: Review /opt/de_sandbox/deployment/README.md"
        echo -e "  2. For single-host: Run install.sh in component directories"
    fi
    exit 0
else
    echo -e "\n${RED}⚠ Please fix the failed checks before proceeding${NC}"
    exit 1
fi
