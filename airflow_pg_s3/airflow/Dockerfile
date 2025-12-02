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

ENV SPARK_VERSION=3.4.4
ENV HADOOP_VERSION=3
ENV SPARK_HOME=/opt/spark
ENV JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
ENV PATH="$SPARK_HOME/bin:$PATH"

RUN curl -fsSL https://archive.apache.org/dist/spark/spark-${SPARK_VERSION}/spark-${SPARK_VERSION}-bin-hadoop${HADOOP_VERSION}.tgz \
    | tar -xz -C /opt && \
    mv /opt/spark-${SPARK_VERSION}-bin-hadoop${HADOOP_VERSION} ${SPARK_HOME}

COPY airflow/.airflow.env /opt/airflow/.airflow.env

COPY airflow/entrypoint-wrapper.sh /entrypoint-wrapper.sh
RUN chmod +x /entrypoint-wrapper.sh

USER airflow

COPY airflow/requirements.txt /tmp/requirements.txt
RUN python3.11 -m pip install --upgrade pip
RUN python3.11 -m pip install --no-cache-dir -r /tmp/requirements.txt

ENTRYPOINT ["/entrypoint-wrapper.sh"]
