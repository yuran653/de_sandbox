#!/bin/bash

# Generates <client>.ovpn for an OpenVPN client with split tunneling
# Usage: ./generate_client_ovpn.sh <client_name> [service_subnet]
# Example: ./generate_client_ovpn.sh client1 10.8.0.0/24

set -euo pipefail

if [ -z "${1:-}" ]; then
    echo "Usage: $0 <client_name> [service_subnets]"
    echo "Example: $0 client1 '10.10.0.0/24 10.104.0.0/20'"
    exit 1
fi

CLIENT_NAME="$1"
SERVICE_SUBNETS="${2:-10.10.0.0/24 10.104.0.0/20}"  # Default VPN subnets
VPN_DIR="/etc/openvpn"
EASY_RSA_DIR="${VPN_DIR}/easy-rsa"
OUTPUT_DIR="${PWD}"
OUTPUT_FILE="${OUTPUT_DIR}/${CLIENT_NAME}.ovpn"

# Check if client cert already exists
if [ -f "${EASY_RSA_DIR}/pki/issued/${CLIENT_NAME}.crt" ]; then
    echo "Certificate for ${CLIENT_NAME} already exists."
else
    echo "Generating certificate for ${CLIENT_NAME}..."
    cd "${EASY_RSA_DIR}"
    ./easyrsa build-client-full "${CLIENT_NAME}" nopass
fi

# Get Public IP
if ! command -v curl >/dev/null 2>&1; then
    echo "curl not found, cannot determine public IP."
    exit 1
fi
PUBLIC_IP=$(curl -s ifconfig.me)

echo "Generating ${OUTPUT_FILE}..."

# Create .ovpn file with split tunneling (only service subnet via VPN)
cat > "${OUTPUT_FILE}" <<EOF
client
dev tun
proto udp
remote ${PUBLIC_IP} 1194
resolv-retry infinite
nobind
user nobody
group nogroup
persist-key
persist-tun
remote-cert-tls server
cipher AES-256-GCM
auth SHA256
verb 3
key-direction 1

# Route service subnets through VPN tunnel
for subnet in ${SERVICE_SUBNETS}; do
    echo "route ${subnet}" >> "${OUTPUT_FILE}"
done
EOF

# Append CA, Cert, Key, TA Key
echo "<ca>" >> "${OUTPUT_FILE}"
cat "${VPN_DIR}/ca.crt" >> "${OUTPUT_FILE}"
echo "</ca>" >> "${OUTPUT_FILE}"

echo "<cert>" >> "${OUTPUT_FILE}"
awk '/BEGIN/,/END/' "${EASY_RSA_DIR}/pki/issued/${CLIENT_NAME}.crt" >> "${OUTPUT_FILE}"
echo "</cert>" >> "${OUTPUT_FILE}"

echo "<key>" >> "${OUTPUT_FILE}"
cat "${EASY_RSA_DIR}/pki/private/${CLIENT_NAME}.key" >> "${OUTPUT_FILE}"
echo "</key>" >> "${OUTPUT_FILE}"

echo "<tls-auth>" >> "${OUTPUT_FILE}"
cat "${VPN_DIR}/ta.key" >> "${OUTPUT_FILE}"
echo "</tls-auth>" >> "${OUTPUT_FILE}"

echo "Done! Client config saved to ${OUTPUT_FILE}"
echo "Services accessible only via VPN tunnel on subnets: ${SERVICE_SUBNETS}"
echo "All other traffic routes normally (split tunneling)"
