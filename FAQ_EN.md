# FAQ: VPN Connection and Service Access

## Download OpenVPN Client
Download the OpenVPN client from the official website: https://openvpn.net/client/

## Connecting to VPN
1. Install the OpenVPN client on your computer
2. Get the `.ovpn` configuration file from the server administrator
3. Import the configuration file into the OpenVPN client
4. Connect to VPN. After connecting, you will see a new network interface

## Accessing Services via VPN
After connecting to VPN, you can access the following services only through the VPN tunnel

- **Airflow Web UI**:
  - http://10.10.0.5:8080
- **MinIO S3 Console**:
  - http://10.10.0.5:9001
- **MinIO S3 API endpoint**:
  - http://10.10.0.5:9000
- **PostgreSQL Databases**:
  - Airflow Metadata DB: 10.10.0.5:5433
  - Datalake DB: 10.10.0.5:5432

- **Database names, logins and passwords: get from the server administrator**

**Important**: All other internet traffic will go through your regular internet provider (split tunneling). Services are available only via VPN

## Troubleshooting and other connection questions
- Contact the server administrator

## Security
- Never share the `.ovpn` file with third parties
- When VPN is disconnected, access to services will be blocked