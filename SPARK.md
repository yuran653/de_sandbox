# Spark Stack Overview 🔧

This document describes the Spark stack found in `de_sandbox/spark` — what services are installed, how they are configured, and operational notes.

---

## Services (defined in `docker-compose.yaml`) 🚀

- **spark-master**
  - Container name: `spark-master`
  - Role: Spark master (cluster manager)
  - CPU / memory (container limits): `cpus: 0.3`, `mem_limit: 0.8g`
  - Command: runs `org.apache.spark.deploy.master.Master` with `${HOST_IP}:${MASTER_PORT}`
  - Important mounts:
    - `./master/spark-defaults.conf` → `/opt/spark/conf/spark-defaults.conf`
    - `./spark-env.sh` → `/opt/spark/conf/spark-env.sh`
    - `spark_events` volume → `/var/spark-events`
  - Healthcheck: `pgrep -f org.apache.spark.deploy.master.Master`

- **spark-worker-1** and **spark-worker-2**
  - Container names: `spark-worker-1`, `spark-worker-2`
  - Role: Spark worker nodes (executors run here)
  - CPU / memory (container limits): `cpus: 0.6`, `mem_limit: 1.2g` (each)
  - Command: runs `org.apache.spark.deploy.worker.Worker` and connects to the master at `spark://${HOST_IP}:${MASTER_PORT}`
  - Important mounts:
    - `./workers/spark-defaults.conf` → `/opt/spark/conf/spark-defaults.conf`
    - `./spark-env.sh` → `/opt/spark/conf/spark-env.sh`
    - `spark_events` → `/var/spark-events`
  - Depends on `spark-master` (only after master is healthy)
  - Healthcheck: `pgrep -f 'org.apache.spark.deploy.worker.Worker'`

- **spark-jupyter**
  - Container name: `spark-jupyter`
  - Role: JupyterLab for running PySpark notebooks
  - CPU / memory (container limits): `cpus: 0.3`, `mem_limit: 0.5g`
  - Environment sets Python executable and `SPARK_MASTER=spark://${HOST_IP}:${MASTER_PORT}`
  - Command: `python3.11 -m jupyter lab --ip=0.0.0.0 --port=8888 --no-browser --allow-root --NotebookApp.token='' --NotebookApp.password=''`
  - Notebooks path: `./jupyter/notebooks` → `/opt/spark/notebooks`
  - Healthcheck: `curl -s http://localhost:8888` (simple liveness test)

---

## Build image (`build/Dockerfile`) 🧱

- Base: `spark:3.4.4`
- Builds and installs **Python 3.11** from source and sets `PYSPARK_PYTHON`/`PYSPARK_DRIVER_PYTHON` to `/usr/local/bin/python3.11`.
- Installs Python packages from `build/requirements.txt` (S3, ClickHouse, pandas, pyarrow, etc.) and Jupyter (JupyterLab 4 / notebook 7).
- Creates `/opt/spark/notebooks` and sets ownership to the Spark non-root user (UID 185).

Files of interest:
- `build/Dockerfile`
- `build/requirements.txt` (contains boto3, pandas, pyarrow, s3fs, clickhouse libs, etc.)

---

## Spark configuration highlights 🔍

- `master/spark-defaults.conf`:
  - Adjusts UI retention and local dir (e.g. `spark.local.dir=/tmp/spark-master`).

- `workers/spark-defaults.conf`:
  - Configures executor defaults (e.g. `spark.executor.cores=1`, `spark.executor.memory=2g`, `spark.executor.memoryOverhead=512m`), worker cleanup and timeouts, `spark.eventLog.dir=/var/spark-events`.

- `spark-env.sh` sets `SPARK_LOCAL_IP` and `SPARK_PUBLIC_DNS` for the host.

Important note: the per-container `mem_limit` for workers is `1.2g`, while `spark.executor.memory` is set to `2g` in `workers/spark-defaults.conf`. This mismatch can cause OOMs or janky behavior; ensure container memory >= executor memory + overhead.

---

## Volumes & Persistence 💾

- `spark_events` (declared in `docker-compose.yaml`) is bound to host `/spark_events` and used for `spark.eventLog.dir` and history server logs.

---

## Networking & Startup 🛠️

- `network_mode: host` is used — containers share the host network namespace.
- Service startup: `docker compose up -d` from `de_sandbox/spark` will build the `custom-spark:3.4.4` image and start services.
- Workers use `depends_on: condition: service_healthy` to wait for the master to be healthy.

---

## Scripts & Ops ⚙️

- `scripts/docker_install.sh` — installs Docker and Docker Compose on Debian (pins specific versions).
- `scripts/setup_routing.sh` — adds a static route to reach remote subnets via a designated host (WG_HOST).

---

## Security & Production Notes ⚠️

- Jupyter is configured with no token/password (`--NotebookApp.token='' --NotebookApp.password=''`) — **this is insecure** on non-private networks. Add authentication or restrict access via network/firewall when exposing externally.
- Verify heap/memory configuration: executor memory values in Spark conf must fit inside container `mem_limit` (plus overhead) to avoid OOM.
- Consider lowering executor memory or increasing container memory if running real jobs.
- Consider enabling TLS/auth for web UIs and Jupyter in production.

---

## Quick checklist for production readiness ✅

- [ ] Align `spark.executor.memory` and `mem_limit` (container)
- [ ] Secure Jupyter (token/password or reverse proxy + auth)
- [ ] Configure log rotation and retention for `/var/spark-events`
- [ ] Ensure appropriate ulimits and `spark.local.dir` space
- [ ] Monitor containers (CPU, memory), Spark UI, and logs

---

If you'd like, I can:
- Generate a small diagram of the service relationships, or
- Add a suggested production configuration (memory, CPU) tuned for a specific VPS size.

*File generated from analysis of `de_sandbox/spark` on disk.*
