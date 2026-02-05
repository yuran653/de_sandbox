# Network Configuration Guide

## Overview
This guide explains how to configure the private network infrastructure for the distributed data engineering platform on DigitalOcean.

## Network Topology

```
Internet
    |
    v
[VPS 1: 10.104.0.2] --- Public IP (Ingress)
    |
    +---------------- Private Network (10.104.0.0/24) ----------------+
    |                                                                  |
[VPS 2: 10.104.0.3]                                            [VPS 3: 10.104.0.4]
(Compute - Private only)                                       (Analytics - Private only)
```

## Prerequisites
- DigitalOcean account with API access
- Three Debian 12 droplets created
- VPC configured with CIDR 10.104.0.0/24

## DigitalOcean VPC Configuration

### Step 1: Create VPC via Web Console

1. **Log into DigitalOcean**
   - Navigate to https://cloud.digitalocean.com

2. **Create VPC**
   - Go to: Networking → VPC
   - Click "Create VPC Network"

3. **Configure VPC Settings**
   ```
   Name: de-sandbox-vpc
   Description: Private network for DE Sandbox platform
   Region: <your-preferred-region>
   IP Range: 10.104.0.0/24
   ```

4. **Create the VPC**
   - Click "Create VPC Network"
   - Note the VPC ID for later use

### Step 2: Create VPC via CLI (Alternative)

If you prefer using the DigitalOcean CLI tool (`doctl`):

```bash
# Install doctl
snap install doctl
doctl auth init

# Create VPC
doctl vpcs create \
  --name de-sandbox-vpc \
  --region <your-region> \
  --ip-range 10.104.0.0/24 \
  --description "Private network for DE Sandbox"

# List VPCs
doctl vpcs list
```

## Droplet (VPS) Configuration

### Step 3: Create Droplets with Private IPs

#### VPS 1 - Ingress & Orchestration
```bash
doctl compute droplet create vps-1-ingress \
  --region <your-region> \
  --size s-4vcpu-8gb \
  --image debian-12-x64 \
  --vpc-uuid <vpc-id> \
  --enable-private-networking \
  --ssh-keys <your-ssh-key-id>
```

**Configuration:**
- Public IP: Assigned automatically
- Private IP: 10.104.0.2 (assign after creation)

#### VPS 2 - Compute Layer
```bash
doctl compute droplet create vps-2-compute \
  --region <your-region> \
  --size s-8vcpu-16gb \
  --image debian-12-x64 \
  --vpc-uuid <vpc-id> \
  --enable-private-networking \
  --ssh-keys <your-ssh-key-id> \
  --enable-ipv6=false
```

**Configuration:**
- Public IP: DO NOT assign
- Private IP: 10.104.0.3 (assign after creation)

#### VPS 3 - Analytics Layer
```bash
doctl compute droplet create vps-3-analytics \
  --region <your-region> \
  --size s-4vcpu-8gb \
  --image debian-12-x64 \
  --vpc-uuid <vpc-id> \
  --enable-private-networking \
  --ssh-keys <your-ssh-key-id> \
  --enable-ipv6=false
```

**Configuration:**
- Public IP: DO NOT assign
- Private IP: 10.104.0.4 (assign after creation)

### Step 4: Assign Static Private IPs

DigitalOcean typically assigns private IPs automatically within the VPC range. To ensure specific IPs:

1. **Check assigned IPs**
   ```bash
   doctl compute droplet list --format Name,PublicIPv4,PrivateIPv4
   ```

2. **If IPs don't match expected values:**
   - You may need to use reserved IPs
   - Or configure network interfaces manually (see below)

## Manual Network Interface Configuration

If you need to manually configure the private network interface on each VPS:

### On VPS 1 (10.104.0.2)

```bash
# Edit network configuration
cat > /etc/systemd/network/10-vpc.network << EOF
[Match]
Name=eth1

[Network]
Address=10.104.0.2/24
EOF

# Restart networking
systemctl restart systemd-networkd

# Verify
ip addr show eth1
```

### On VPS 2 (10.104.0.3)

```bash
cat > /etc/systemd/network/10-vpc.network << EOF
[Match]
Name=eth1

[Network]
Address=10.104.0.3/24
Gateway=10.104.0.2
EOF

systemctl restart systemd-networkd
ip addr show eth1
```

### On VPS 3 (10.104.0.4)

```bash
cat > /etc/systemd/network/10-vpc.network << EOF
[Match]
Name=eth1

[Network]
Address=10.104.0.4/24
Gateway=10.104.0.2
EOF

systemctl restart systemd-networkd
ip addr show eth1
```

## Routing Configuration

### On VPS 1 (Gateway)

VPS 1 acts as the gateway for VPS 2 and VPS 3:

```bash
# Enable IP forwarding
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
sysctl -p

# Configure NAT for outbound traffic from private network
# (This allows VPS 2 and VPS 3 to reach internet for updates)
nft add table nat
nft add chain nat postrouting { type nat hook postrouting priority 100 \; }
nft add rule nat postrouting ip saddr 10.104.0.0/24 oifname "eth0" masquerade

# Save nftables rules
nft list ruleset > /etc/nftables.conf
```

### On VPS 2 and VPS 3

Configure VPS 1 as default gateway for internet access:

```bash
# Add route for internet access via VPS 1
ip route add default via 10.104.0.2 dev eth1

# Make it persistent
cat >> /etc/network/interfaces << EOF

# Route internet traffic through VPS 1
up ip route add default via 10.104.0.2 dev eth1 || true
EOF
```

## DNS Configuration

Configure DNS resolution on all VPS instances:

```bash
# On all VPS instances
cat >> /etc/hosts << EOF

# DE Sandbox cluster nodes
10.104.0.2  vps1 vps-ingress
10.104.0.3  vps2 vps-compute
10.104.0.4  vps3 vps-analytics
EOF
```

## Firewall Configuration

### VPS 1 - Ingress Node

Allow external access to VPN and minimal services:

```bash
# Basic nftables rules
nft add table inet filter
nft add chain inet filter input { type filter hook input priority 0 \; policy drop \; }
nft add chain inet filter forward { type filter hook forward priority 0 \; policy accept \; }
nft add chain inet filter output { type filter hook output priority 0 \; policy accept \; }

# Allow established connections
nft add rule inet filter input ct state established,related accept

# Allow loopback
nft add rule inet filter input iif lo accept

# Allow SSH
nft add rule inet filter input tcp dport 22 accept

# Allow WireGuard VPN
nft add rule inet filter input udp dport 51820 accept

# Allow from private network
nft add rule inet filter input ip saddr 10.104.0.0/24 accept

# Allow ping
nft add rule inet filter input icmp type echo-request accept

# Save rules
nft list ruleset > /etc/nftables.conf
```

### VPS 2 and VPS 3 - Internal Nodes

These should only accept connections from the private network:

```bash
# Basic nftables rules
nft add table inet filter
nft add chain inet filter input { type filter hook input priority 0 \; policy drop \; }
nft add chain inet filter output { type filter hook output priority 0 \; policy accept \; }

# Allow established connections
nft add rule inet filter input ct state established,related accept

# Allow loopback
nft add rule inet filter input iif lo accept

# Allow from private network only
nft add rule inet filter input ip saddr 10.104.0.0/24 accept

# Allow ping
nft add rule inet filter input icmp type echo-request accept

# Save rules
nft list ruleset > /etc/nftables.conf
```

## Network Verification

### Test connectivity between VPS instances:

```bash
# From VPS 1
ping -c 3 10.104.0.3  # Should work
ping -c 3 10.104.0.4  # Should work

# From VPS 2
ping -c 3 10.104.0.2  # Should work
ping -c 3 10.104.0.4  # Should work

# From VPS 3
ping -c 3 10.104.0.2  # Should work
ping -c 3 10.104.0.3  # Should work
```

### Test service connectivity:

```bash
# From VPS 1, test if you can reach services on other VPS
# (after services are deployed)

# Test Spark on VPS 2
curl -f http://10.104.0.3:8080

# Test ClickHouse on VPS 3
curl -f http://10.104.0.4:8123/ping
```

## Troubleshooting

### Cannot ping between VPS instances
- Verify VPC configuration in DigitalOcean console
- Check that all droplets are in the same VPC
- Verify private IP addresses are correctly assigned
- Check firewall rules (nftables)

### VPS 2/3 cannot access internet
- Verify IP forwarding is enabled on VPS 1
- Check NAT rules on VPS 1
- Verify default gateway on VPS 2 and VPS 3 points to 10.104.0.2
- Test: `ip route get 8.8.8.8`

### Services not accessible from other VPS
- Check if services are listening on the correct interface
- Use `ss -tulpn` to verify listening ports
- Check firewall rules
- Verify Docker network mode (should be `host` for cross-VPS communication)

### DNS resolution issues
- Verify `/etc/hosts` contains correct entries
- Test: `getent hosts vps2`
- Check `/etc/resolv.conf` for nameservers

## Security Best Practices

1. **Minimize attack surface**
   - Only VPS 1 should have a public IP
   - Use VPN (WireGuard) for administrative access
   - Disable password authentication for SSH

2. **Network segmentation**
   - Keep compute and analytics layers isolated from public internet
   - Use firewall rules to restrict traffic

3. **Monitoring**
   - Monitor network traffic
   - Set up alerts for unusual activity
   - Regular security audits

4. **Updates**
   - Keep all systems updated
   - Test updates in development environment first

## References

- [DigitalOcean VPC Documentation](https://docs.digitalocean.com/products/networking/vpc/)
- [DigitalOcean Private Networking](https://docs.digitalocean.com/products/networking/vpc/how-to/configure-droplet/)
- [nftables Documentation](https://wiki.nftables.org/)
- [WireGuard Documentation](https://www.wireguard.com/quickstart/)
