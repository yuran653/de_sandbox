#!/usr/bin/env bash

# Generates de_sandbox_XX.conf for a WireGuard client
# Usage: ./generate_client_config.sh < client_public.key

set -euo pipefail

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'  # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WG_INTERFACE="de_sandbox"
WG_CONF_PATH="/etc/wireguard/${WG_INTERFACE}.conf"
SERVER_PUBLIC_KEY_FILE="/etc/wireguard/publickey"
WG_PRIVATE_KEY_FILE="/etc/wireguard/privatekey"
server_public_key=""
client_public_key=""
server_ip=""

append_peer_entry() {
  if grep -q "PublicKey = ${client_public_key}" "$WG_CONF_PATH"; then
    echo -e "${RED}Peer with this public key already exists in ${WG_CONF_PATH}${NC}" >&2
    exit 1
  fi

  {
    printf '\n'
    printf '[Peer]\n'
    printf 'PublicKey = %s\n' "$client_public_key"
    printf 'AllowedIPs = 10.10.0.%s/32\n' "$host_number"
  } >> "$WG_CONF_PATH" || {
    echo -e "${RED}Failed to append peer entry to ${WG_CONF_PATH}${NC}" >&2
    exit 1
  }
  echo -e "${GREEN}Peer entry appended successfully.${NC}"
  echo -e "${YELLOW}Restarting WireGuard interface...${NC}"
  systemctl restart wg-quick@de_sandbox
  echo -e "${GREEN}WireGuard interface restarted.${NC}"
  echo -e "${YELLOW}Showing WireGuard status...${NC}"
  wg show
  echo -e "${GREEN}WireGuard status displayed.${NC}"
}

ensure_server_public_key() {
  if [ -r "$WG_CONF_PATH" ] && [ -r "$SERVER_PUBLIC_KEY_FILE" ] && [ -r "$WG_PRIVATE_KEY_FILE" ]; then
    server_public_key="$(tr -d '\r\n' < "$SERVER_PUBLIC_KEY_FILE")"
    if [ -n "$server_public_key" ]; then
      echo -e "${GREEN}Server public key is found.${NC}"
      return 0
    fi
  fi

  generate_server_artifacts

  if [ -r "$SERVER_PUBLIC_KEY_FILE" ]; then
    server_public_key="$(tr -d '\r\n' < "$SERVER_PUBLIC_KEY_FILE")"
  fi

  if [ -z "$server_public_key" ]; then
    echo -e "${RED}Unable to determine or generate the server public key${NC}" >&2
    exit 1
  fi
  echo -e "${GREEN}Server public key ensured.${NC}"
}

read_client_public_key() {
  local raw
  raw="$(cat - 2>/dev/null)"
  raw="${raw//$'\r'/}"
  raw="${raw//$'\n'/}"
  raw="${raw// /}"
  if ! valid_public_key "$raw"; then
    echo -e "${RED}Client public key invalid or empty${NC}" >&2
    exit 1
  fi
  client_public_key="$raw"
  echo -e "${GREEN}Client public key read successfully.${NC}"
}

find_next_host() {
  for host in $(seq 2 254); do
    if ! grep -q "10\.10\.0\.${host}/32" "$WG_CONF_PATH"; then
      echo -e "${GREEN}Next host found: 10.10.0.${host}${NC}" >&2
      echo "$host"
      return 0
    fi
  done
  echo -e "${RED}No free client slots remain in 10.10.0.0/24${NC}" >&2
  exit 1
}

get_server_ip() {
  if ! command -v curl >/dev/null 2>&1; then
    echo -e "${RED}curl command not found, cannot determine server IP${NC}" >&2
    exit 1
  fi
  server_ip=$(curl -s --max-time 10 ifconfig.me)
  if [ -z "$server_ip" ]; then
    echo -e "${RED}Failed to determine server IP${NC}" >&2
    exit 1
  fi
  echo -e "${GREEN}Server IP determined: $server_ip${NC}"
}

generate_server_artifacts() {
  if ! command -v wg >/dev/null 2>&1; then
    echo -e "${RED}wg command not found${NC}" >&2
    exit 1
  fi

  umask 077
  mkdir -p /etc/wireguard

  if [ ! -r "$WG_PRIVATE_KEY_FILE" ]; then
    if ! wg genkey > "$WG_PRIVATE_KEY_FILE" 2>/dev/null; then
      echo -e "${RED}Failed to generate server private key${NC}" >&2
      exit 1
    fi
  fi

  if [ ! -r "$SERVER_PUBLIC_KEY_FILE" ]; then
    if ! wg pubkey < "$WG_PRIVATE_KEY_FILE" > "$SERVER_PUBLIC_KEY_FILE" 2>/dev/null; then
      echo -e "${RED}Failed to derive server public key${NC}" >&2
      exit 1
    fi
  fi

  if [ ! -r "$WG_CONF_PATH" ]; then
    server_private_key="$(tr -d '\r\n' < "$WG_PRIVATE_KEY_FILE")"
    cat > "$WG_CONF_PATH" <<EOF
[Interface]
Address = 10.10.0.1/24
ListenPort = 51820
PrivateKey = ${server_private_key}
# Add peer blocks below
EOF
  fi
  echo -e "${GREEN}Server artifacts generated.${NC}"
}

valid_public_key() {
  local key="$1"
  [[ ${#key} -eq 44 && "$key" =~ ^[A-Za-z0-9+/]{43}=$ ]]
}

echo -e "${YELLOW}1. Generating client WireGuard config...${NC}"
get_server_ip
host_number="$(find_next_host)"
printf -v suffix "%02d" "$host_number"

echo -e "${YELLOW}2. Reading client public key from stdin...${NC}"
read_client_public_key

echo -e "${YELLOW}3. Ensuring server public key is available...${NC}"
ensure_server_public_key

echo -e "${YELLOW}4. Appending peer entry to server config...${NC}"
append_peer_entry

output_file="${SCRIPT_DIR}/de_sandbox_${suffix}.conf"
if [ -e "$output_file" ]; then
  echo -e "${RED}$output_file already exists. Remove it or rename before rerunning.${NC}" >&2
  exit 1
fi

echo -e "${YELLOW}5. Writing client configuration to ${output_file}...${NC}"
cat > "$output_file" <<EOF
# Client WireGuard config for de_sandbox peer ${suffix}
# Client public key: ${client_public_key}

[Interface]
# Paste the client private key in place of <CLIENT_PRIVATE_KEY>
PrivateKey = <CLIENT_PRIVATE_KEY>
Address = 10.10.0.${host_number}/32
DNS = 1.1.1.1

[Peer]
PublicKey = ${server_public_key}
Endpoint = ${server_ip}:51820
AllowedIPs = 10.104.0.0/20
PersistentKeepalive = 25
EOF
echo -e "${GREEN}Client configuration written successfully.${NC}"
echo -e "${GREEN}Wrote ${output_file}${NC}"
