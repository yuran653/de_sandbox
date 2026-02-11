# DE Sandbox — Data Engineering Sandbox / Песочница для Data Engineering

## English ✅
**DE Sandbox** is a compact multi-VPS data engineering environment consisting of three nodes:
- **VPS_1:** Airflow + PostgreSQL + MinIO (Docker Compose)
- **VPS_2:** ClickHouse cluster (Docker Compose)
- **VPS_3:** Spark cluster on K3s + Jupyter (Kubernetes)

Nodes are connected via an OpenVPN gateway; routing and access from the public Internet are implemented via OpenVPN. Use `airflow_pg_s3/etc/generate_client_ovpn.sh` to create a client `.ovpn` file for VPN access. Installation scripts and configuration are provided in the corresponding folders: `airflow_pg_s3/`, `clickhouse/`, and `spark/`.

Quick start:
- Run component installers: `./airflow_pg_s3/install.sh`, `./clickhouse/install.sh`, `./spark/install.sh`
- Verify services: `docker ps`, `kubectl get pods -n spark`.

VPN access URLs (via OpenVPN):
- Airflow UI: http://10.104.0.5:8080
- PostgreSQL (Airflow Metadata): tcp://10.104.0.5:5433
- PostgreSQL (Datalake): tcp://10.104.0.5:5432
- MinIO Console: http://10.104.0.5:9001
- MinIO S3 API (TCP): tcp://10.104.0.5:9000

ClickHouse endpoints (per node):
- ClickHouse Node 1 (shard 1): HTTP: http://10.104.0.2:8123 | Native: tcp://10.104.0.2:9000
- ClickHouse Node 2 (shard 2): HTTP: http://10.104.0.2:18123 | Native: tcp://10.104.0.2:19000
- ZooKeeper: tcp://10.104.0.2:2181

Spark UI endpoints:
- Spark Master UI: http://10.104.0.4:30080
- Jupyter Lab: http://10.104.0.4:30888

Configuration files and manifests are located in the component folders: `airflow_pg_s3/`, `clickhouse/`, and `spark/`.

---

## Русский ✅
**DE Sandbox** — компактная мульти-VPS среда для Data Engineering, состоящая из трех узлов:
- **VPS_1:** Airflow + PostgreSQL + MinIO (Docker Compose)
- **VPS_2:** Кластер ClickHouse (Docker Compose)
- **VPS_3:** Кластер Spark на K3s + Jupyter (Kubernetes)

Узлы связаны через OpenVPN-шлюз; маршрутизация и доступ из интернета реализованы через OpenVPN. Для получения клиентского конфигурационного файла `.ovpn` используйте `airflow_pg_s3/etc/generate_client_ovpn.sh`. Скрипты установки и конфигурации находятся в папках: `airflow_pg_s3/`, `clickhouse/`, `spark/`.

Быстрый старт:
- Запустите установщики: `./airflow_pg_s3/install.sh`, `./clickhouse/install.sh`, `./spark/install.sh`
- Проверьте сервисы: `docker ps`, `kubectl get pods -n spark`.

VPN-адреса для доступа (через OpenVPN):
- Airflow UI: http://10.104.0.5:8080
- PostgreSQL (Airflow Metadata): tcp://10.104.0.5:5433
- PostgreSQL (Datalake): tcp://10.104.0.5:5432
- MinIO Console: http://10.104.0.5:9001
- MinIO S3 API (TCP): tcp://10.104.0.5:9000

ClickHouse — адреса по узлам (шардам):
- ClickHouse Узел 1 (шард 1): HTTP: http://10.104.0.2:8123 | Native: tcp://10.104.0.2:9000
- ClickHouse Узел 2 (шард 2): HTTP: http://10.104.0.2:18123 | Native: tcp://10.104.0.2:19000
- ZooKeeper: tcp://10.104.0.2:2181

Spark UI:
- Spark Master UI: http://10.104.0.4:30080
- Jupyter Lab: http://10.104.0.4:30888

Файлы конфигурации и манифесты находятся в папках: `airflow_pg_s3/`, `clickhouse/`, `spark/`.
