"""
Example DAG demonstrating end-to-end data pipeline across the distributed DE Sandbox platform.

This DAG demonstrates:
1. Reading data from MinIO (VPS 1)
2. Processing with Spark (VPS 2)
3. Writing results to ClickHouse (VPS 3)

Prerequisites:
- All three VPS instances deployed and running
- Airflow connections configured:
  - spark_default: spark://10.104.0.3:7077
  - clickhouse_default: host=10.104.0.4, port=9000
- MinIO bucket created: test-bucket
"""

from datetime import datetime, timedelta
from airflow import DAG
from airflow.operators.python import PythonOperator
from airflow.providers.apache.spark.operators.spark_submit import SparkSubmitOperator
from airflow.operators.bash import BashOperator

default_args = {
    'owner': 'de_sandbox',
    'depends_on_past': False,
    'start_date': datetime(2024, 1, 1),
    'email_on_failure': False,
    'email_on_retry': False,
    'retries': 1,
    'retry_delay': timedelta(minutes=5),
}

dag = DAG(
    'example_multi_vps_pipeline',
    default_args=default_args,
    description='End-to-end data pipeline across VPS 1, 2, and 3',
    schedule_interval=None,  # Manual trigger only
    catchup=False,
    tags=['example', 'multi-vps', 'spark', 'clickhouse'],
)


def generate_test_data():
    """Generate sample CSV data and upload to MinIO (VPS 1)"""
    import io
    import csv
    from datetime import datetime
    from minio import Minio
    
    # MinIO connection details (VPS 1)
    minio_client = Minio(
        "10.104.0.2:9000",
        access_key="42Bangkok",  # Use your actual credentials
        secret_key="LadKrabang",
        secure=False
    )
    
    # Ensure bucket exists
    bucket_name = "test-bucket"
    if not minio_client.bucket_exists(bucket_name):
        minio_client.make_bucket(bucket_name)
    
    # Generate sample data
    data = []
    for i in range(1000):
        data.append({
            'id': i,
            'timestamp': datetime.now().isoformat(),
            'value': i * 10,
            'category': f'category_{i % 5}'
        })
    
    # Write to CSV in memory
    csv_buffer = io.StringIO()
    writer = csv.DictWriter(csv_buffer, fieldnames=['id', 'timestamp', 'value', 'category'])
    writer.writeheader()
    writer.writerows(data)
    
    # Upload to MinIO
    csv_bytes = csv_buffer.getvalue().encode('utf-8')
    minio_client.put_object(
        bucket_name,
        'input/test_data.csv',
        io.BytesIO(csv_bytes),
        length=len(csv_bytes),
        content_type='text/csv'
    )
    
    print(f"Uploaded {len(data)} rows to MinIO at 10.104.0.2:9000/{bucket_name}/input/test_data.csv")


def verify_clickhouse_data():
    """Verify data was written to ClickHouse (VPS 3)"""
    from clickhouse_driver import Client
    
    # ClickHouse connection (VPS 3)
    client = Client(
        host='10.104.0.4',
        port=9000,
        database='ch_datalake'
    )
    
    # Check if table exists and has data
    result = client.execute('SELECT count() FROM test_results')
    count = result[0][0]
    
    print(f"ClickHouse table 'test_results' contains {count} rows")
    
    # Show sample data
    sample = client.execute('SELECT * FROM test_results LIMIT 5')
    print("Sample data:")
    for row in sample:
        print(row)
    
    if count == 0:
        raise ValueError("No data found in ClickHouse table!")


# Task 1: Generate test data and upload to MinIO (VPS 1)
generate_data_task = PythonOperator(
    task_id='generate_test_data',
    python_callable=generate_test_data,
    dag=dag,
)

# Task 2: Process data with Spark (VPS 2)
# Note: This requires a Spark application script
spark_process_task = BashOperator(
    task_id='spark_process_data',
    bash_command="""
    # This is a simplified example. In production, use SparkSubmitOperator
    # with a proper PySpark script
    
    echo "Simulating Spark job on VPS 2 (10.104.0.3)"
    echo "Reading from MinIO: s3a://test-bucket/input/test_data.csv"
    echo "Processing data..."
    echo "Writing to ClickHouse: jdbc:clickhouse://10.104.0.4:9000/ch_datalake"
    
    # In a real scenario, this would submit a job like:
    # spark-submit --master spark://10.104.0.3:7077 \
    #   --conf spark.hadoop.fs.s3a.endpoint=http://10.104.0.2:9000 \
    #   --conf spark.hadoop.fs.s3a.access.key=$ACCESS_KEY \
    #   --conf spark.hadoop.fs.s3a.secret.key=$SECRET_KEY \
    #   /path/to/spark_job.py
    """,
    dag=dag,
)

# Task 3: Create ClickHouse table (VPS 3)
create_ch_table_task = BashOperator(
    task_id='create_clickhouse_table',
    bash_command="""
    # Connect to ClickHouse and create table if not exists
    # This uses docker exec to run clickhouse-client from Airflow
    
    echo "Creating ClickHouse table on VPS 3 (10.104.0.4)"
    
    # Note: Adjust this command based on your setup
    # If running from VPS 1, you might need to SSH to VPS 3 or use HTTP interface
    
    curl -X POST 'http://10.104.0.4:8123/' \
      --data-binary "CREATE TABLE IF NOT EXISTS ch_datalake.test_results (
        id UInt32,
        timestamp DateTime,
        value Int32,
        category String
      ) ENGINE = MergeTree()
      ORDER BY (id, timestamp)"
    
    echo "Table created successfully"
    """,
    dag=dag,
)

# Task 4: Verify data in ClickHouse
verify_data_task = PythonOperator(
    task_id='verify_clickhouse_data',
    python_callable=verify_clickhouse_data,
    dag=dag,
)

# Define task dependencies
generate_data_task >> create_ch_table_task >> spark_process_task >> verify_data_task
