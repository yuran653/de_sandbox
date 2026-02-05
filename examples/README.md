# Example DAGs and Pipelines

This directory contains example DAGs and supporting files that demonstrate how to use the distributed DE Sandbox platform.

## Available Examples

### example_multi_vps_pipeline.py
Demonstrates an end-to-end data pipeline across all three VPS instances:
- **VPS 1**: Data generation and upload to MinIO (S3-compatible storage)
- **VPS 2**: Data processing with Apache Spark
- **VPS 3**: Results storage in ClickHouse for analytics

## Using the Examples

### 1. Deploy the Platform
First, ensure all three VPS instances are deployed and running:
```bash
# On VPS 1
/opt/de_sandbox/deployment/vps1-deploy.sh

# On VPS 3
/opt/de_sandbox/deployment/vps3-deploy.sh

# On VPS 2
/opt/de_sandbox/deployment/vps2-deploy.sh
```

### 2. Copy DAGs to Airflow
Copy the example DAGs to your Airflow DAGs directory:
```bash
# On VPS 1
cp /opt/de_sandbox/examples/dags/*.py /airflow/dags/
```

### 3. Configure Airflow Connections
Access the Airflow UI via VPN (http://10.104.0.2:8080) and configure these connections:

#### Spark Connection
- Connection Id: `spark_default`
- Connection Type: `Spark`
- Host: `10.104.0.3`
- Port: `7077`

#### ClickHouse Connection
- Connection Id: `clickhouse_default`
- Connection Type: `Generic`
- Host: `10.104.0.4`
- Port: `9000`
- Login: (optional, depends on your config)
- Password: (optional, depends on your config)

### 4. Run the Example DAG
1. Open Airflow UI: http://10.104.0.2:8080
2. Find `example_multi_vps_pipeline` in the DAGs list
3. Enable the DAG (toggle on the left)
4. Click on the DAG name
5. Click "Trigger DAG" button

### 5. Monitor Execution
Watch the DAG execution:
- View task logs in Airflow UI
- Check Spark jobs in Spark Master UI: http://10.104.0.3:8080
- Verify data in ClickHouse:
  ```bash
  # SSH to VPS 3
  docker exec -it clickhouse-01 clickhouse-client --port 9000
  
  # Query the data
  SELECT * FROM ch_datalake.test_results LIMIT 10;
  ```

## Creating Your Own DAGs

### Best Practices
1. **Always use the private network IPs**:
   - VPS 1 (Airflow, MinIO): `10.104.0.2`
   - VPS 2 (Spark): `10.104.0.3`
   - VPS 3 (ClickHouse): `10.104.0.4`

2. **Use Airflow connections**: Define connections in Airflow UI instead of hardcoding credentials

3. **Handle retries**: Configure appropriate retry logic for network operations

4. **Monitor resources**: Be aware of resource limits on each VPS

### Template for New DAGs
```python
from datetime import datetime, timedelta
from airflow import DAG
from airflow.operators.python import PythonOperator

default_args = {
    'owner': 'your_name',
    'depends_on_past': False,
    'start_date': datetime(2024, 1, 1),
    'email_on_failure': False,
    'retries': 1,
    'retry_delay': timedelta(minutes=5),
}

dag = DAG(
    'your_dag_name',
    default_args=default_args,
    description='Your DAG description',
    schedule_interval=None,
    catchup=False,
    tags=['your', 'tags'],
)

def your_task_function():
    # Your code here
    pass

task = PythonOperator(
    task_id='your_task',
    python_callable=your_task_function,
    dag=dag,
)
```

## Troubleshooting

### DAG not appearing in Airflow UI
- Check that the file is in `/airflow/dags/`
- Verify file has `.py` extension
- Check Airflow scheduler logs: `docker compose logs -f airflow-scheduler`

### Connection errors between VPS instances
- Verify all services are running: `docker ps`
- Test network connectivity: `ping 10.104.0.x`
- Check firewall rules on each VPS
- Verify services are listening on correct interfaces: `ss -tulpn`

### Spark job submission fails
- Verify Spark master is accessible: `curl http://10.104.0.3:8080`
- Check Spark connection in Airflow is configured correctly
- Review Spark master logs: `docker compose logs -f spark-master`

### ClickHouse connection issues
- Test ClickHouse connectivity: `curl http://10.104.0.4:8123/ping`
- Verify cluster is healthy: `docker exec clickhouse-01 clickhouse-client --query 'SELECT 1'`
- Check ClickHouse logs: `docker compose logs -f clickhouse-01`

## Additional Resources

- [Apache Airflow Documentation](https://airflow.apache.org/docs/)
- [Apache Spark Documentation](https://spark.apache.org/docs/latest/)
- [ClickHouse Documentation](https://clickhouse.com/docs)
- [MinIO Python Client](https://min.io/docs/minio/linux/developers/python/minio-py.html)

## Contributing

Feel free to add your own example DAGs to this directory! Please include:
- Clear comments explaining what the DAG does
- Prerequisites and required configurations
- Expected inputs and outputs
- Any special dependencies
