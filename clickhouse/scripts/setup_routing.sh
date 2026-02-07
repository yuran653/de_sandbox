#!/bin/bash
set -e

WG_HOST='10.104.0.5'

BLUE='\033[1;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}Starting Routing Setup${NC}"

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
ip route add 10.10.0.0/24 via $WG_HOST

echo -e "${GREEN}Routing setup completed successfully!${NC}"
