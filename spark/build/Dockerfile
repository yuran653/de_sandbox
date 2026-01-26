FROM spark:3.4.4

USER root

# Install build dependencies for Python source build
RUN apt update && apt install -y \
    wget \
    build-essential \
    libffi-dev \
    libssl-dev \
    zlib1g-dev \
    liblzma-dev \
    libbz2-dev \
    libreadline-dev \
    libsqlite3-dev \
    libncurses5-dev \
    libgdbm-dev \
    libnss3-dev \
    libxml2-dev \
    libxmlsec1-dev \
    tk-dev \
    && rm -rf /var/lib/apt/lists/*

# Build Python 3.11 from source
WORKDIR /tmp

RUN wget https://www.python.org/ftp/python/3.11.9/Python-3.11.9.tgz && \
    tar -xzf Python-3.11.9.tgz && \
    cd Python-3.11.9 && \
    ./configure --enable-optimizations && \
    make -j"$(nproc)" && \
    make altinstall && \
    ln -s /usr/local/bin/python3.11 /usr/bin/python3.11 && \
    rm -rf /tmp/Python-3.11.9 /tmp/Python-3.11.9.tgz

# Set Python for pyspark
ENV PYSPARK_PYTHON=/usr/local/bin/python3.11
ENV PYSPARK_DRIVER_PYTHON=/usr/local/bin/python3.11

# Upgrade pip
RUN /usr/local/bin/python3.11 -m pip install --upgrade pip

# Copy and install requirements
COPY build/requirements.txt /opt/spark/requirements.txt
RUN /usr/local/bin/python3.11 -m pip install --no-cache-dir -r /opt/spark/requirements.txt

# Install Jupyter
RUN /usr/local/bin/python3.11 -m pip install --no-cache-dir \
    jupyter==1.0.0 \
    jupyterlab==4.0.9 \
    notebook==7.0.6

# Create notebooks directory
RUN mkdir -p /opt/spark/notebooks && chown -R 185:185 /opt/spark/notebooks

# Return Spark image non-root user
USER 185
