#!/bin/bash

# WireGuard VPN Installation Script for Debian 12
# Installs WireGuard + nftables, creates server keys and config, enables forwarding,
# and applies a restrictive nftables policy: only SSH and WireGuard are reachable from outside.
# VPN clients can reach host services and the internet per NAT rules.

set -euo pipefail

BLUE='\033[1;34m'
GREEN='\033[0;32m'
NC='\033[0m'

WG_INTERFACE="de_sandbox"
WG_DIR="/etc/wireguard"
WG_CONF="${WG_DIR}/${WG_INTERFACE}.conf"
WG_SUBNET="10.10.0.0/24"
WG_ADDR="10.10.0.1/24"
WG_PORT="51820"

# Using eth0 as public interface
PUB_IF="eth0"

echo -e "${BLUE}Updating packages and installing WireGuard + nftables${NC}"
apt update
apt install -y wireguard wireguard-tools nftables lsof

echo -e "${BLUE}Enable IPv4 forwarding persistently${NC}"
echo "net.ipv4.ip_forward=1" | tee /etc/sysctl.d/99-wireguard.conf > /dev/null
sysctl -p /etc/sysctl.d/99-wireguard.conf

echo -e "${BLUE}Creating WireGuard directory and generating keys${NC}"
mkdir -p "${WG_DIR}"
chmod 700 "${WG_DIR}"

WG_PRIVATE_KEY=$(wg genkey)
WG_PUBLIC_KEY=$(echo "${WG_PRIVATE_KEY}" | wg pubkey)

echo "${WG_PRIVATE_KEY}" | tee "${WG_DIR}/privatekey" > /dev/null
echo "${WG_PUBLIC_KEY}"  | tee "${WG_DIR}/publickey" > /dev/null
chmod 600 "${WG_DIR}/privatekey" "${WG_DIR}/publickey"

echo -e "${BLUE}Creating WireGuard config at ${WG_CONF}${NC}"
cat <<EOF | tee "${WG_CONF}" > /dev/null
[Interface]
Address = ${WG_ADDR}
ListenPort = ${WG_PORT}
PrivateKey = ${WG_PRIVATE_KEY}
SaveConfig = false

# Add [Peer] blocks for VPN clients manually
EOF

chmod 600 "${WG_CONF}"

echo -e "${BLUE}Enabling and starting WireGuard service (${WG_INTERFACE})${NC}"
systemctl enable --now "wg-quick@${WG_INTERFACE}"

echo -e "${BLUE}Writing nftables configuration to /etc/nftables.conf${NC}"
if [ -f "./etc/nftables.conf" ]; then
  cp ./etc/nftables.conf /etc/nftables.conf
else
  echo "ERROR: ./etc/nftables.conf not found" >&2
  exit 1
fi

echo -e "${BLUE}Enabling nftables${NC}"
systemctl enable nftables

echo -e "${BLUE}Applying nftables rules${NC}"
systemctl restart nftables

echo -e "${BLUE}Active nftables ruleset:${NC}"
nft list ruleset

echo -e "${GREEN}WireGuard + nftables installation completed successfully${NC}"
