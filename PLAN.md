# Implementation Plan for Distributed Data Engineering Architecture

## Overview
This plan outlines the steps to transform the current single-host Docker Compose setup into a distributed, multi-VPS architecture as described in CONFIGURATION.md. The target architecture consists of three VPS instances on DigitalOcean connected via a private network (10.104.0.0/24).

## Current State Analysis

### What Exists
- ✅ Docker Compose configurations for all components (Airflow, Spark, ClickHouse)
- ✅ Installation scripts for single-host deployment
- ✅ Dockerfiles and build configurations
- ✅ Basic networking using host mode
- ✅ Volume configurations for data persistence

### Gap Analysis
- ❌ Multi-host deployment configurations
- ❌ Private network (10.104.0.0/24) setup
- ❌ VPS-specific deployment scripts
- ❌ Inter-VPS communication configuration
- ❌ OpenVPN/WireGuard setup for secure access
- ❌ Service discovery across hosts
- ❌ Firewall rules and security configurations

## Architecture Target

### VPS 1 (10.104.0.2) - Ingress & Orchestration
- **Components**: Airflow, PostgreSQL (Metadata + OLTP), MinIO
- **Role**: Single entry point, orchestration, storage
- **Access**: Public internet access, OpenVPN gateway

### VPS 2 (10.104.0.3) - Compute Layer
- **Components**: Spark Cluster (Master + Workers), Jupyter Notebook
- **Role**: Distributed processing
- **Access**: Private network only

### VPS 3 (10.104.0.4) - Analytics Layer
- **Components**: ClickHouse Cluster (2 nodes), Zookeeper
- **Role**: OLAP storage and queries
- **Access**: Private network only

## Implementation Steps

### Phase 1: Network Infrastructure Setup
1. **Configure Private Network on DigitalOcean**
   - Create VPC with CIDR 10.104.0.0/24
   - Assign static IPs to VPS instances
   - Configure network interfaces on each VPS

2. **Setup VPN Gateway on VPS 1**
   - Install and configure WireGuard/OpenVPN
   - Configure nftables firewall rules
   - Create client configuration templates
   - Document VPN access procedures

3. **Configure Inter-VPS Routing**
   - Enable IP forwarding on VPS 1
   - Setup routing tables for private network
   - Configure DNS resolution for service discovery

### Phase 2: VPS-Specific Deployment Configurations

#### VPS 1 Configuration
1. **Update docker-compose.yaml for Airflow stack**
   - Configure services to bind to private network interface
   - Update connection strings to use private IPs
   - Add environment variables for remote service endpoints

2. **Create deployment script**
   - System preparation (directories, permissions)
   - Docker and Docker Compose installation
   - VPN setup integration
   - Firewall configuration
   - Service deployment

3. **Configure service discovery**
   - Setup /etc/hosts or DNS for service names
   - Document service endpoints and ports

#### VPS 2 Configuration
1. **Update docker-compose.yaml for Spark cluster**
   - Configure Spark master to advertise on private IP
   - Update worker connections to use private network
   - Configure S3 (MinIO) connection to VPS 1
   - Setup Jupyter to connect to remote Spark master

2. **Create deployment script**
   - System preparation
   - Docker installation
   - Network routing setup
   - Service deployment

3. **Configure resource allocation**
   - Optimize Spark worker memory and CPU settings
   - Configure event log sharing

#### VPS 3 Configuration
1. **Update docker-compose.yaml for ClickHouse cluster**
   - Configure ClickHouse nodes for cluster operation
   - Setup Zookeeper for coordination
   - Configure network bindings for private network

2. **Create deployment script**
   - System preparation
   - Docker installation
   - Network routing setup
   - Cluster initialization

3. **Configure cluster replication**
   - Setup distributed tables
   - Configure shard distribution
   - Test cluster connectivity

### Phase 3: Service Integration

1. **Airflow → Spark Integration**
   - Configure SparkSubmitOperator with remote master URL
   - Setup connection to S3 (MinIO) on VPS 1
   - Test DAG execution with remote Spark

2. **Spark → ClickHouse Integration**
   - Configure JDBC connections to ClickHouse
   - Setup write operations to distributed tables
   - Test data pipeline

3. **Airflow → ClickHouse Integration**
   - Configure ClickHouse connection in Airflow
   - Test query operations
   - Setup monitoring queries

### Phase 4: Security Hardening

1. **Firewall Configuration**
   - VPS 1: Allow only necessary public ports (VPN, Airflow UI)
   - VPS 2: Block all public access
   - VPS 3: Block all public access
   - Configure inter-VPS firewall rules

2. **Service Authentication**
   - Setup authentication for all services
   - Configure secure credentials management
   - Implement SSL/TLS where applicable

3. **Access Control**
   - Document VPN access procedures
   - Create user management guidelines
   - Setup audit logging

### Phase 5: Documentation and Testing

1. **Deployment Documentation**
   - Step-by-step deployment guide for each VPS
   - Network configuration guide
   - Service connection details
   - Troubleshooting guide

2. **Testing**
   - Verify inter-service connectivity
   - Test end-to-end data pipeline
   - Validate failover scenarios
   - Performance testing

3. **Monitoring Setup**
   - Document health check endpoints
   - Setup basic monitoring
   - Create alerting guidelines

## Implementation Priority

### Critical Path (Must Have)
1. Private network configuration (Phase 1.1)
2. Docker Compose updates for private network (Phase 2)
3. Service connectivity testing (Phase 3)
4. Basic firewall rules (Phase 4.1)

### Important (Should Have)
1. VPN gateway setup (Phase 1.2)
2. Comprehensive deployment scripts (Phase 2)
3. Security hardening (Phase 4.2, 4.3)

### Nice to Have (Could Have)
1. Monitoring and alerting
2. Automated failover
3. Advanced routing configurations

## File Changes Required

### New Files to Create
- `PLAN.md` (this file)
- `airflow_pg_s3/docker-compose.vps1.yaml` - VPS 1 specific configuration
- `spark/docker-compose.vps2.yaml` - VPS 2 specific configuration
- `clickhouse/docker-compose.vps3.yaml` - VPS 3 specific configuration
- `deployment/vps1-deploy.sh` - VPS 1 deployment script
- `deployment/vps2-deploy.sh` - VPS 2 deployment script
- `deployment/vps3-deploy.sh` - VPS 3 deployment script
- `deployment/network-setup.md` - Network configuration guide
- `deployment/README.md` - Deployment instructions

### Files to Modify
- `airflow_pg_s3/docker-compose.yaml` - Add private network support
- `spark/docker-compose.yaml` - Configure for remote connectivity
- `clickhouse/docker-compose.yaml` - Setup for distributed operation
- `README.md` - Update with multi-host deployment instructions
- `airflow_pg_s3/.env` - Add network configuration variables
- `spark/.env` - Add remote connection variables
- `clickhouse/.env` - Add cluster configuration variables

## Risk Assessment

### Technical Risks
- Network latency between VPS instances
- Service discovery complexity
- Configuration management across multiple hosts
- Data consistency in distributed setup

### Mitigation Strategies
- Use private network for low latency
- Implement proper health checks and retries
- Use configuration management tools
- Follow ClickHouse best practices for replication

## Success Criteria

1. ✅ All three VPS instances can communicate via private network
2. ✅ Airflow can successfully trigger Spark jobs on VPS 2
3. ✅ Spark can read from MinIO on VPS 1
4. ✅ Spark can write to ClickHouse on VPS 3
5. ✅ Only VPS 1 is accessible from public internet
6. ✅ VPN provides secure access to internal services
7. ✅ All services start automatically on boot
8. ✅ Comprehensive documentation exists for deployment and operations

## Timeline Estimate

- Phase 1: Network Infrastructure - 2-3 hours
- Phase 2: VPS Configurations - 4-6 hours
- Phase 3: Service Integration - 2-3 hours
- Phase 4: Security Hardening - 2-3 hours
- Phase 5: Documentation and Testing - 2-3 hours

**Total Estimated Time**: 12-18 hours

## Next Steps

1. Review and approve this plan
2. Begin Phase 1 implementation
3. Test each phase before moving to the next
4. Document any deviations or issues encountered
5. Update this plan as needed based on implementation experience
