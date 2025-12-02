FROM zookeeper:3.7

RUN apt-get update \
    && apt-get install -y --no-install-recommends netcat \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

COPY build/zoo.cfg /conf/zoo.cfg
