# FAQ: VPN Connection and Service Access

## Download WireGuard Client
Download the WireGuard client from the official website: https://www.wireguard.com/install/

## Connecting to VPN
1. Install the WireGuard client on your computer
2. Get the `.conf` configuration file from the server administrator
3. Import the configuration file into the WireGuard client
4. Connect to VPN. After connecting, you will see a new network interface

## Accessing Services via VPN
After connecting to VPN, you can access the following services only through the VPN tunnel

### VPS_1 (Airflow + PostgreSQL + MinIO) - 10.104.0.5
- **Airflow Web UI**:
  - http://10.104.0.5:8080
- **MinIO S3 Console**:
  - http://10.104.0.5:9001
- **MinIO S3 API endpoint**:
  - http://10.104.0.5:9000
- **PostgreSQL Databases**:
  - Airflow Metadata DB: 10.104.0.5:5433
  - Datalake DB: 10.104.0.5:5432

### VPS_2 (ClickHouse) - 10.104.0.2
- **ClickHouse HTTP Interface**:
  - http://10.104.0.2:8123
- **ClickHouse Native Protocol**:
  - 10.104.0.2:9000

### VPS_3 (Spark + Jupyter) - 10.104.0.3
- **Spark Master Web UI**:
  - http://10.104.0.3:30080
- **Jupyter Lab**:
  - http://10.104.0.3:30888

**Database names, logins and passwords: get from the server administrator**

**Important**: All other internet traffic will go through your regular internet provider (split tunneling). Services are available only via VPN

## Troubleshooting and other connection questions
- Contact the server administrator

## Security
- Never share the `.conf` file with third parties
- When VPN is disconnected, access to services will be blocked