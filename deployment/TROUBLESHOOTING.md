# Troubleshooting Guide for Multi-VPS Deployment

This guide covers common issues and their solutions when deploying and operating the DE Sandbox platform across multiple VPS instances.

## Table of Contents
1. [Network Connectivity Issues](#network-connectivity-issues)
2. [Service Deployment Problems](#service-deployment-problems)
3. [Inter-Service Communication](#inter-service-communication)
4. [Performance Issues](#performance-issues)
5. [Data Pipeline Failures](#data-pipeline-failures)
6. [Security and Access Issues](#security-and-access-issues)

---

## Network Connectivity Issues

### Cannot ping between VPS instances

**Symptoms:**
```bash
# From VPS 1
ping 10.104.0.3
# Request timeout or "Destination Host Unreachable"
```

**Diagnosis:**
```bash
# Check network interfaces
ip addr show

# Check routing table
ip route show

# Check if VPC is configured correctly in DigitalOcean console
```

**Solutions:**
1. **Verify VPC Configuration**:
   - Log into DigitalOcean console
   - Navigate to Networking → VPC
   - Ensure all droplets are in the same VPC
   - Verify IP range is 10.104.0.0/24

2. **Check Network Interface**:
   ```bash
   # Verify private network interface is up
   ip link show eth1
   
   # If down, bring it up
   ip link set eth1 up
   ```

3. **Check Firewall Rules**:
   ```bash
   # List current nftables rules
   nft list ruleset
   
   # Temporarily allow all traffic for testing
   nft flush ruleset
   ```

4. **Verify Static IP Assignment**:
   ```bash
   # Check if correct IP is assigned
   ip addr show eth1 | grep 10.104.0
   ```

### VPS 2 and VPS 3 cannot access internet

**Symptoms:**
- Cannot run `apt update`
- Cannot pull Docker images
- DNS resolution fails

**Diagnosis:**
```bash
# Test internet connectivity
ping -c 3 8.8.8.8

# Check default gateway
ip route get 8.8.8.8

# Check DNS resolution
nslookup google.com
```

**Solutions:**
1. **Configure Default Gateway** (on VPS 2 and VPS 3):
   ```bash
   # Add default route through VPS 1
   ip route add default via 10.104.0.2 dev eth1
   
   # Make it persistent
   echo "up ip route add default via 10.104.0.2 dev eth1 || true" >> /etc/network/interfaces
   ```

2. **Enable IP Forwarding on VPS 1**:
   ```bash
   # Enable IP forwarding
   echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
   sysctl -p
   
   # Verify it's enabled
   cat /proc/sys/net/ipv4/ip_forward  # Should output: 1
   ```

3. **Configure NAT on VPS 1**:
   ```bash
   # Add NAT rule
   nft add table nat
   nft add chain nat postrouting { type nat hook postrouting priority 100 \; }
   nft add rule nat postrouting ip saddr 10.104.0.0/24 oifname "eth0" masquerade
   
   # Save rules
   nft list ruleset > /etc/nftables.conf
   ```

---

## Service Deployment Problems

### Docker containers fail to start

**Symptoms:**
```bash
docker ps
# Shows containers in "Restarting" or "Exited" state
```

**Diagnosis:**
```bash
# Check container logs
docker compose logs <service-name>

# Check Docker daemon logs
journalctl -u docker -n 50

# Check disk space
df -h

# Check memory usage
free -h
```

**Solutions:**
1. **Insufficient Resources**:
   ```bash
   # Check available resources
   free -h
   df -h
   
   # Reduce resource limits in docker-compose.yaml if needed
   # Edit mem_limit and cpus values
   ```

2. **Port Conflicts**:
   ```bash
   # Check what's using a port
   ss -tulpn | grep <port>
   
   # Kill conflicting process or change port in configuration
   ```

3. **Volume Permission Issues**:
   ```bash
   # Fix volume permissions
   chown -R 50000:50000 /airflow/*  # Airflow UID
   chown -R 999:999 /pg_*             # PostgreSQL UID
   chown -R 1000:1000 /minio_datalake # MinIO UID
   chmod -R 755 /spark_events
   ```

4. **Missing Directories**:
   ```bash
   # Recreate required directories
   mkdir -p /airflow/{dags,logs,plugins,scripts}
   mkdir -p /spark_events
   mkdir -p /pg_metadata /pg_datalake
   mkdir -p /minio_datalake
   mkdir -p /clickhouse/{zk/{data,logs},01/{data,logs},02/{data,logs}}
   ```

### Docker images fail to build

**Symptoms:**
```bash
docker compose build
# Error during build process
```

**Solutions:**
1. **Network Issues**:
   ```bash
   # Ensure internet connectivity
   ping -c 3 8.8.8.8
   
   # Configure Docker to use different DNS
   cat > /etc/docker/daemon.json << EOF
   {
     "dns": ["8.8.8.8", "8.8.4.4"]
   }
   EOF
   systemctl restart docker
   ```

2. **Disk Space**:
   ```bash
   # Clean up Docker resources
   docker system prune -a
   
   # Check space again
   df -h
   ```

---

## Inter-Service Communication

### Airflow cannot connect to Spark

**Symptoms:**
- Spark jobs fail to submit
- Connection timeout errors in Airflow logs

**Diagnosis:**
```bash
# From VPS 1, test Spark Master connectivity
curl http://10.104.0.3:8080

# Check Spark Master is listening
# SSH to VPS 2
ss -tulpn | grep 8080
```

**Solutions:**
1. **Verify Spark Master is Running**:
   ```bash
   # On VPS 2
   docker ps | grep spark-master
   docker compose logs spark-master
   ```

2. **Check Network Connectivity**:
   ```bash
   # From VPS 1
   telnet 10.104.0.3 7077
   telnet 10.104.0.3 8080
   ```

3. **Update Airflow Connection**:
   - Access Airflow UI: http://10.104.0.2:8080
   - Go to Admin → Connections
   - Edit or create spark_default:
     - Connection Type: Spark
     - Host: 10.104.0.3
     - Port: 7077

### Spark cannot read from MinIO

**Symptoms:**
- Spark jobs fail with S3 connection errors
- "Connection refused" or "Access denied" errors

**Diagnosis:**
```bash
# From VPS 2, test MinIO connectivity
curl http://10.104.0.2:9000/minio/health/live

# Check if credentials are correct
```

**Solutions:**
1. **Verify MinIO Credentials in Spark Config**:
   ```bash
   # On VPS 2, check spark/.env
   cat /opt/de_sandbox/spark/.env
   # Ensure S3_ACCESS_KEY and S3_SECRET_KEY match VPS 1 MinIO credentials
   ```

2. **Update Spark Configuration**:
   ```bash
   # Edit spark-defaults.conf
   spark.hadoop.fs.s3a.endpoint=http://10.104.0.2:9000
   spark.hadoop.fs.s3a.access.key=<YOUR_ACCESS_KEY>
   spark.hadoop.fs.s3a.secret.key=<YOUR_SECRET_KEY>
   spark.hadoop.fs.s3a.path.style.access=true
   spark.hadoop.fs.s3a.impl=org.apache.hadoop.fs.s3a.S3AFileSystem
   ```

3. **Test MinIO Connection**:
   ```bash
   # From VPS 2, using mc (MinIO Client)
   mc alias set minio http://10.104.0.2:9000 <ACCESS_KEY> <SECRET_KEY>
   mc ls minio/
   ```

### Spark cannot write to ClickHouse

**Symptoms:**
- Spark jobs fail during write phase
- JDBC connection errors

**Diagnosis:**
```bash
# From VPS 2, test ClickHouse connectivity
curl http://10.104.0.4:8123/ping

# Test TCP connection
telnet 10.104.0.4 9000
```

**Solutions:**
1. **Verify ClickHouse is Running**:
   ```bash
   # On VPS 3
   docker ps | grep clickhouse
   docker exec clickhouse-01 clickhouse-client --query "SELECT 1"
   ```

2. **Check ClickHouse JDBC Driver**:
   Ensure Spark has ClickHouse JDBC driver in its classpath:
   ```bash
   # Add to spark-defaults.conf
   spark.jars=/path/to/clickhouse-jdbc-driver.jar
   ```

3. **Test Direct Connection**:
   ```bash
   # From VPS 2, using clickhouse-client
   docker run --rm -it clickhouse/clickhouse-client \
     --host 10.104.0.4 --port 9000 \
     --query "SELECT 1"
   ```

---

## Performance Issues

### Slow query performance in ClickHouse

**Solutions:**
1. **Check Resource Usage**:
   ```bash
   # On VPS 3
   docker stats clickhouse-01 clickhouse-02
   ```

2. **Optimize Table Schema**:
   - Use appropriate ORDER BY columns
   - Consider partitioning for large tables
   - Use compression codecs

3. **Monitor Query Performance**:
   ```bash
   # Check slow queries
   docker exec clickhouse-01 clickhouse-client \
     --query "SELECT query, elapsed FROM system.query_log ORDER BY elapsed DESC LIMIT 10"
   ```

### Spark jobs running slowly

**Solutions:**
1. **Increase Worker Resources**:
   ```bash
   # Edit spark/docker-compose.yaml
   # Increase mem_limit and cpus for workers
   ```

2. **Optimize Spark Configuration**:
   ```bash
   # Edit spark-defaults.conf
   spark.executor.memory=4g
   spark.executor.cores=2
   spark.default.parallelism=8
   ```

3. **Check Data Locality**:
   - Ensure data is stored efficiently in MinIO
   - Use partitioning in S3 paths

---

## Data Pipeline Failures

### DAG fails with connection timeout

**Solutions:**
1. **Increase Airflow Task Timeout**:
   ```python
   # In your DAG file
   default_args = {
       'execution_timeout': timedelta(hours=2),
   }
   ```

2. **Check Network Stability**:
   ```bash
   # Monitor network between VPS instances
   ping -i 1 10.104.0.3  # Keep running to check for packet loss
   ```

### Data not appearing in ClickHouse

**Diagnosis:**
```bash
# Check if data was written
docker exec clickhouse-01 clickhouse-client \
  --query "SELECT count() FROM <your_table>"

# Check for errors in ClickHouse logs
docker compose logs clickhouse-01 | grep -i error
```

**Solutions:**
1. **Verify Table Schema Matches Data**:
   ```sql
   DESC <your_table>
   ```

2. **Check for Failed Inserts**:
   ```sql
   SELECT * FROM system.query_log 
   WHERE query LIKE '%INSERT%' AND exception != ''
   ```

---

## Security and Access Issues

### Cannot access services via VPN

**Symptoms:**
- VPN connects but cannot access services
- Timeout when accessing 10.104.0.x addresses

**Solutions:**
1. **Verify VPN is Connected**:
   ```bash
   # On client machine
   wg show
   ip route | grep 10.104.0
   ```

2. **Check VPN Server Configuration** (on VPS 1):
   ```bash
   # Verify WireGuard is running
   systemctl status wg-quick@de_sandbox
   
   # Check configuration
   cat /etc/wireguard/de_sandbox.conf
   ```

3. **Add Client Routes**:
   ```bash
   # On client machine
   sudo ip route add 10.104.0.0/24 via <vpn_gateway>
   ```

### Permission denied errors

**Solutions:**
1. **Check File Permissions**:
   ```bash
   # Fix volume permissions
   ls -la /airflow /pg_metadata /minio_datalake
   
   # Fix if needed
   chown -R <appropriate_uid>:<appropriate_gid> <directory>
   ```

2. **SELinux Issues** (if applicable):
   ```bash
   # Check SELinux status
   sestatus
   
   # Temporarily disable for testing
   setenforce 0
   ```

---

## General Debugging Commands

### View Service Status
```bash
# All services
docker compose ps

# Specific service logs
docker compose logs -f <service-name>

# Follow all logs
docker compose logs -f
```

### Check Resource Usage
```bash
# System resources
htop

# Docker resources
docker stats

# Disk usage
df -h
du -sh /airflow/* /pg_* /minio_datalake /clickhouse/*
```

### Network Debugging
```bash
# Test connectivity
ping -c 3 <ip>
telnet <ip> <port>
curl http://<ip>:<port>

# Check listening ports
ss -tulpn

# Trace route
traceroute <ip>

# DNS resolution
nslookup <hostname>
```

### Service Health Checks
```bash
# Airflow
curl http://10.104.0.2:8080/health

# MinIO
curl http://10.104.0.2:9000/minio/health/live

# Spark Master
curl http://10.104.0.3:8080

# ClickHouse
curl http://10.104.0.4:8123/ping
```

---

## Getting Help

If you're still experiencing issues:

1. **Check Logs**: Always check service logs first
2. **Review Configuration**: Verify all .env files and configurations
3. **Test Network**: Ensure all VPS instances can communicate
4. **Check Resources**: Verify sufficient CPU, memory, and disk space
5. **Consult Documentation**: Review component-specific docs
6. **Open an Issue**: If problem persists, open a GitHub issue with:
   - Description of the problem
   - Steps to reproduce
   - Relevant logs
   - System configuration details
