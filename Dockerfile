# 使用 Ubuntu 24.04 作为基础镜像
FROM ubuntu:24.04

# 设置时区和更新软件包
ENV TZ=UTC
RUN apt-get update && apt-get install -y --no-install-recommends \
    openjdk-8-jre wget tar net-tools && \
    rm -rf /var/lib/apt/lists/*

# 设置 Zookeeper 版本
ENV ZOOKEEPER_VERSION=3.8.4
ENV ZOOKEEPER_HOME=/opt/zookeeper
ENV PATH=$ZOOKEEPER_HOME/bin:$PATH

# 下载并安装 Zookeeper
RUN wget -q "https://dlcdn.apache.org/zookeeper/zookeeper-${ZOOKEEPER_VERSION}/apache-zookeeper-${ZOOKEEPER_VERSION}-bin.tar.gz" && \
    tar -xzf "apache-zookeeper-${ZOOKEEPER_VERSION}-bin.tar.gz" -C /opt && \
    mv /opt/apache-zookeeper-${ZOOKEEPER_VERSION}-bin $ZOOKEEPER_HOME && \
    rm "apache-zookeeper-${ZOOKEEPER_VERSION}-bin.tar.gz"

# 配置 Zookeeper 数据目录和日志目录
RUN mkdir -p /data/zookeeper /logs/zookeeper /opt/sh
# 添加默认配置文件
COPY ./config/zookeeper/zoo.cfg $ZOOKEEPER_HOME/conf/zoo.cfg
COPY ./config/sh/write_myid.sh /opt/sh/write_myid.sh
RUN chmod 777 /opt/sh/write_myid.sh
# 暴露端口
EXPOSE 2181 2888 3888

# 启动 Zookeeper
CMD ["/opt/sh/write_myid.sh"]