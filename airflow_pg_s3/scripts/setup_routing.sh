#!/bin/bash
set -e

WG_HOST='10.104.0.5'

BLUE='\033[1;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}Starting Routing Setup for Airflow${NC}"

echo -e "${YELLOW}Installing required packages...${NC}"
apt install -y iproute2 net-tools lsof

echo -e "${YELLOW}Configuring static routes...${NC}"

mkdir -p /etc/network/interfaces.d
FILE="/etc/network/interfaces.d/static_routes"

cat > "$FILE" <<EOF
up ip route add 10.10.0.0/24 via $WG_HOST
down ip route del 10.10.0.0/24 via $WG_HOST
EOF

chmod 644 "$FILE"

echo -e "${YELLOW}Applying static route immediately...${NC}"
ip route add 10.10.0.0/24 via $WG_HOST || true

echo -e "${YELLOW}Enabling IP forwarding...${NC}"
sysctl -w net.ipv4.ip_forward=1

mkdir -p /etc/sysctl.d
echo "net.ipv4.ip_forward=1" > /etc/sysctl.d/99-ip-forward.conf

echo -e "${YELLOW}Configuring firewall rules for Airflow services...${NC}"

# Airflow Web Server
nft add rule inet filter INPUT tcp dport 8080 accept comment "Airflow Web UI" || true

# PostgreSQL - Airflow metadata database
nft add rule inet filter INPUT tcp dport 5433 accept comment "PostgreSQL Airflow metadata" || true

# PostgreSQL - Datalake database
nft add rule inet filter INPUT tcp dport 5432 accept comment "PostgreSQL Datalake" || true

# MinIO S3-compatible storage
nft add rule inet filter INPUT tcp dport 9000 accept comment "MinIO API" || true
nft add rule inet filter INPUT tcp dport 9001 accept comment "MinIO Console" || true

echo -e "${GREEN}Routing and firewall setup completed successfully!${NC}"
