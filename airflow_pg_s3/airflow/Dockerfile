FROM apache/airflow:2.8.4-python3.11

USER root

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        git \
        pkg-config \
        default-libmysqlclient-dev \
        build-essential \
        openjdk-17-jdk \
        procps \
        curl \
        ca-certificates && \
    rm -rf /var/lib/apt/lists/*

ENV JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64

COPY airflow/.airflow.env /opt/airflow/.airflow.env

COPY airflow/entrypoint-wrapper.sh /entrypoint-wrapper.sh
RUN chmod +x /entrypoint-wrapper.sh

USER airflow

COPY airflow/requirements.txt /tmp/requirements.txt
RUN python3.11 -m pip install --upgrade pip
RUN python3.11 -m pip install --no-cache-dir -r /tmp/requirements.txt

ENTRYPOINT ["/entrypoint-wrapper.sh"]
