#!/bin/bash

# Airflow Initialization and Deployment Script for Debian 12
# This script starts all services,
# initializes Airflow database,
# and creates admin user

set -euo pipefail

BLUE='\033[1;34m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${SCRIPT_DIR}/.."

echo -e "${BLUE}Creating persistent data directories${NC}"
mkdir -p /pg_metadata /pg_datalake /minio_datalake \
    /airflow/{logs,dags,plugins,scripts} \
    /spark_events
# Airflow runs as UID 50000 in the container
chown -R 50000:0 /airflow
chown -R 50000:50000 /spark_events
chmod -R 775 /spark_events
# Get the current user's primary group for Debian 12
USER_GROUP=$(id -gn)
chown "${USER}":"${USER_GROUP}" \
    /pg_metadata /pg_datalake /minio_datalake
chmod -R 775 /airflow
chmod 755 /pg_metadata /pg_datalake /minio_datalake

echo -e "${BLUE}Starting all services${NC}"
docker compose -f "${PROJECT_ROOT}/docker-compose.yaml" \
    up -d --build

echo -e "${BLUE}Waiting for metadata database to be ready${NC}"
MAX_RETRIES=30
RETRY_COUNT=0
until docker exec metadata-db pg_isready \
        -U airflow -p 5433 > /dev/null 2>&1; do
    RETRY_COUNT=$((RETRY_COUNT + 1))
    if [ $RETRY_COUNT -ge $MAX_RETRIES ]; then
        echo -e "${RED}Database failed to start after ${MAX_RETRIES} attempts${NC}"
        exit 1
    fi
    echo "Waiting for database... (attempt $RETRY_COUNT/$MAX_RETRIES)"
    sleep 5
done
echo -e "${GREEN}Database is ready${NC}"

echo -e "${BLUE}Checking service status${NC}"
docker compose ps

echo -e "${GREEN}Deployment of Airflow is complete${NC}"
