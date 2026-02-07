#!/bin/bash

# OpenVPN Installation Script for Debian 12
# Installs OpenVPN + EasyRSA, generates keys, and configures the server.

set -euo pipefail

# Ensure script runs from project root for consistent relative paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${SCRIPT_DIR}/.."
cd "${PROJECT_ROOT}"

BLUE='\033[1;34m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

VPN_DIR="/etc/openvpn"
EASY_RSA_DIR="${VPN_DIR}/easy-rsa"
SERVER_CONF="${VPN_DIR}/server.conf"

echo -e "${BLUE}Updating packages and installing OpenVPN + git${NC}"
apt update
apt install -y openvpn git iptables nftables

echo -e "${BLUE}Setting up EasyRSA${NC}"
mkdir -p "${EASY_RSA_DIR}"
# We'll copy easy-rsa files from /usr/share/easy-rsa if available, otherwise clone/download
# For Debian 12, 'easy-rsa' package installs to /usr/share/easy-rsa
if ! dpkg -s easy-rsa >/dev/null 2>&1; then
    apt install -y easy-rsa
fi
cp -r /usr/share/easy-rsa/* "${EASY_RSA_DIR}/"

cd "${EASY_RSA_DIR}"

# Initialize PKI
echo -e "${BLUE}Initializing PKI...${NC}"
./easyrsa init-pki

# Build CA (headless)
echo -e "${BLUE}Building CA...${NC}"
echo "de_sandbox_ca" | ./easyrsa build-ca nopass

# Generate Server Cert/Key
echo -e "${BLUE}Generating Server Certificate...${NC}"
./easyrsa build-server-full server nopass

# Generate DH params
echo -e "${BLUE}Generating Diffie-Hellman parameters (this may take a while)...${NC}"
./easyrsa gen-dh

# Generate HMAC key for TLS auth
openvpn --genkey --secret pki/ta.key

# Copy artifacts to openvpn dir
cp pki/ca.crt pki/private/server.key pki/issued/server.crt pki/dh.pem pki/ta.key "${VPN_DIR}/"

echo -e "${BLUE}Creating Server Config at ${SERVER_CONF}${NC}"
cat > "${SERVER_CONF}" <<EOF
port 1194
proto udp
dev tun
ca ca.crt
cert server.crt
key server.key
dh dh.pem
tls-auth ta.key 0
topology subnet
# server 10.10.0.0 255.255.255.0
mode server
tls-server
ifconfig 10.10.0.5 255.255.255.0
ifconfig-pool 10.10.0.10 10.10.0.254 255.255.255.0
push "route-gateway 10.10.0.5"
push "topology subnet"
push "dhcp-option DNS 1.1.1.1"
push "dhcp-option DNS 1.0.0.1"
push "route 10.104.0.0 255.255.240.0"
keepalive 10 120
cipher AES-256-GCM
auth SHA256
user nobody
group nogroup
persist-key
persist-tun
status openvpn-status.log
verb 3
explicit-exit-notify 1
EOF

echo -e "${BLUE}Enabling IP Forwarding${NC}"
echo "net.ipv4.ip_forward=1" | tee /etc/sysctl.d/99-openvpn.conf
sysctl -p /etc/sysctl.d/99-openvpn.conf

echo -e "${BLUE}Enabling and Starting OpenVPN service${NC}"
systemctl enable --now openvpn@server

echo -e "${BLUE}Writing nftables configuration to /etc/nftables.conf${NC}"
if [ -f "${PROJECT_ROOT}/etc/nftables.conf" ]; then
  cp "${PROJECT_ROOT}/etc/nftables.conf" /etc/nftables.conf
else
  echo "ERROR: ${PROJECT_ROOT}/etc/nftables.conf not found" >&2
  exit 1
fi

echo -e "${BLUE}Enabling nftables${NC}"
systemctl enable nftables
systemctl restart nftables

echo -e "${GREEN}OpenVPN installation completed successfully!${NC}"
