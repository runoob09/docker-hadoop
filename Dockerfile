# 使用 Ubuntu 24.04 作为基础镜像
FROM ubuntu:24.04

# 设置时区和更新软件包
ENV TZ=UTC
# 更新apt源，安装必备工具包
RUN apt-get update &&  \
    apt-get install -y --no-install-recommends wget tar ssh aria2 ca-certificates openssh-server rsync sshpass&& \
    rm -rf /var/lib/apt/lists/*

# 配置软件的环境变量
ENV ZOOKEEPER_VERSION=3.8.4
ENV HADOOP_VERSION=3.2.4
ENV HBASE_VERSION=2.6.1
ENV ZOOKEEPER_HOME=/opt/zookeeper
ENV JAVA_HOME=/opt/jdk
ENV HADOOP_HOME=/opt/hadoop
ENV HBASE_HOME=/opt/hbase
ENV PATH=$JAVA_HOME/bin:$ZOOKEEPER_HOME/bin:$HADOOP_HOME/bin:$HADOOP_HOME/sbin:$PATH:$HBASE_HOME/bin


# 生成 SSH 密钥对
RUN ssh-keygen -t rsa -f /root/.ssh/id_rsa -q -N "" && \
    cat /root/.ssh/id_rsa.pub >> /root/.ssh/authorized_keys && \
    chmod 600 /root/.ssh/authorized_keys && \
    # 更改密码
    echo "root:20020725" | chpasswd && \
    # 允许root登录
    sed -i 's/^#PermitRootLogin .*/PermitRootLogin yes/' /etc/ssh/sshd_config && \
    sed -i 's/^#\?PubkeyAuthentication .*/PubkeyAuthentication yes/' /etc/ssh/sshd_config && \
    sed -i 's/^#\?PasswordAuthentication .*/PasswordAuthentication yes/' /etc/ssh/sshd_config


# 创建对应的目录
RUN mkdir -p /data/zookeeper /logs/zookeeper /opt/sh /download
# 安装jdk
RUN aria2c -x16 -s16 "https://repo.huaweicloud.com/java/jdk/8u202-b08/jdk-8u202-linux-x64.tar.gz" -o /download/jdk.tar.gz &&\
    tar -xzf /download/jdk.tar.gz -C /opt && \
    mv /opt/jdk* /opt/jdk
# 安装zookeeper
RUN aria2c -x16 -s16 "https://mirrors.tuna.tsinghua.edu.cn/apache/zookeeper/zookeeper-${ZOOKEEPER_VERSION}/apache-zookeeper-${ZOOKEEPER_VERSION}-bin.tar.gz" -o /download/zookeeper.tar.gz &&\
    tar -xzf /download/zookeeper.tar.gz -C /opt && \
    mv /opt/apache-zookeeper-${ZOOKEEPER_VERSION}-bin /opt/zookeeper
# 安装hadoop
RUN aria2c -x16 -s16 "https://mirrors.tuna.tsinghua.edu.cn/apache/hadoop/common/hadoop-${HADOOP_VERSION}/hadoop-${HADOOP_VERSION}.tar.gz" -o /download/hadoop.tar.gz &&\
    tar -xzf /download/hadoop.tar.gz -C /opt && \
    mv /opt/hadoop-${HADOOP_VERSION} /opt/hadoop
# 安装hbase
RUN aria2c -x16 -s16 "https://mirrors.tuna.tsinghua.edu.cn/apache/hbase/${HBASE_VERSION}/hbase-${HBASE_VERSION}-bin.tar.gz" -o /download/hbase.tar.gz &&\
    tar -xzf /download/hbase.tar.gz -C /opt && \
    mv /opt/hbase-${HBASE_VERSION} /opt/hbase




# 配置 Zookeeper 数据目录和日志目录
RUN mkdir -p /data/zookeeper /logs/zookeeper /opt/sh /data/hadoop/datanode /data/hadoop/namenode

# 添加zookeeper配置文件
COPY ./config/zookeeper/zoo.cfg $ZOOKEEPER_HOME/conf/zoo.cfg


# 添加hadoop配置文件
COPY ./config/hadoop/ /opt/hadoop/etc/hadoop/
COPY config/sh/entrypoint.sh /opt/sh/entrypoint.sh

# 配置hbase
COPY ./config/hbase/* /opt/hbase/conf/
COPY ./config/hadoop/core-site.xml /opt/hbase/conf/
COPY ./config/hadoop/hdfs-site.xml /opt/hbase/conf/


# 复制hosts文件
COPY ./config/etc/hosts /etc
# 给脚本添加执行权限
RUN chmod 777 /opt/sh/entrypoint.sh && \
    rm -rf /download

# 设置volume
VOLUME ["/opt/sh"]
# 启动 Zookeeper
CMD ["/bin/bash","/opt/sh/entrypoint.sh"]