#!/bin/bash

# K3s Installation and Spark Cluster Deployment Script
# For Debian 12, 4 CPUs, 8GB RAM
# Updated with actual working configuration

set -euo pipefail

# Color codes
BLUE='\033[1;34m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}K3s Installation and Spark Deployment${NC}"
echo -e "${BLUE}========================================${NC}"

# Ensure we are in the script directory
cd "$(dirname "$0")"

# Step 1: Install Docker (needed to build the Spark image)
echo -e "\n${YELLOW}Step 1/6: Installing Docker${NC}"
apt update
apt install -y ca-certificates curl gnupg

install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null

apt update
apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
systemctl enable docker
systemctl start docker
echo -e "${GREEN}Docker installed successfully${NC}"

# Step 2: Build the Spark Docker image
echo -e "\n${YELLOW}Step 2/6: Building Spark Docker image${NC}"
# We are already in the correct directory
docker build -t custom-spark:3.4.4 -f build/Dockerfile .
echo -e "${GREEN}Spark image built successfully${NC}"

# Step 3: Install K3s with Docker runtime
echo -e "\n${YELLOW}Step 3/6: Installing K3s${NC}"
curl -sfL https://get.k3s.io | \
  K3S_KUBECONFIG_MODE="644" \
  sh -s - \
  --docker \
  --disable=traefik \
  --disable=servicelb \
  --kubelet-arg=max-pods=50 \
  --kubelet-arg=kube-reserved=cpu=100m,memory=256Mi \
  --kubelet-arg=system-reserved=cpu=100m,memory=256Mi

# Wait for K3s to be ready
echo "Waiting for K3s to start..."
sleep 15
until kubectl get nodes | grep -q " Ready"; do
  echo "Waiting for K3s node to be ready..."
  sleep 5
done
echo -e "${GREEN}K3s installed and ready${NC}"

# Step 3.5: Setup routing for multi-VPS communication
echo -e "\n${YELLOW}Step 3.5/6: Setting up network routing${NC}"
if [ -f "./scripts/setup_routing.sh" ]; then
    bash "./scripts/setup_routing.sh"
    echo -e "${GREEN}Network routing configured${NC}"
else
    echo -e "${YELLOW}Warning: setup_routing.sh not found, skipping routing setup${NC}"
fi

# Step 4: With --docker flag, image is already available
echo -e "\n${YELLOW}Step 4/6: Verifying Spark image availability${NC}"
docker images | grep custom-spark && echo -e "${GREEN}Spark image available${NC}"

# Step 5: Create directories
echo -e "\n${YELLOW}Step 5/6: Creating directories${NC}"
mkdir -p /spark_events
chmod 777 /spark_events
mkdir -p ./jupyter
chmod 777 ./jupyter
echo -e "${GREEN}Directories created${NC}"

# Step 6: Deploy Spark components to K3s
echo -e "\n${YELLOW}Step 6/6: Deploying Spark to K3s${NC}"
cd k8s-manifests
kubectl apply -f 01-namespace.yaml
kubectl apply -f 02-configmaps.yaml
kubectl apply -f 03-pvc.yaml
kubectl apply -f 04-spark-master.yaml
sleep 15  # Wait for master to initialize
kubectl apply -f 05-spark-workers.yaml
kubectl apply -f 06-jupyter.yaml

echo -e "\n${BLUE}========================================${NC}"
echo -e "${GREEN}Deployment complete!${NC}"
echo -e "${BLUE}========================================${NC}"

echo -e "\n${YELLOW}Waiting for pods to be ready...${NC}"
sleep 30
kubectl get pods -n spark

NODE_IP=$(hostname -I | awk '{print $1}')
echo -e "\n${GREEN}Access URLs:${NC}"
echo -e "  Spark Master UI: http://${NODE_IP}:30080"
echo -e "  Jupyter Lab:     http://${NODE_IP}:30888"
echo -e "\n${YELLOW}Note: It may take 1-2 minutes for all pods to be fully ready.${NC}"
