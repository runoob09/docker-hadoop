#!/bin/bash

# 启动SSH服务并复制SSH密钥到容器
start_ssh() {
    local log_file="$LOG_DIR/ssh_key_copied.log"

    # 启动SSH服务
    echo "正在启动SSH服务..."
    service ssh start
    sleep 10

    # 检查并复制SSH密钥
    if [[ ! -f "$log_file" ]]; then
        echo "正在复制SSH密钥到容器..."
        for host in "${container[@]}"; do
            echo "正在复制SSH密钥到 $host..."
            sshpass -p "$SSH_PASSWORD" ssh-copy-id -o StrictHostKeyChecking=no root@"$host"
        done
        touch "$log_file"  # 记录密钥复制完成
    else
        echo "SSH密钥已经复制，跳过此步骤。"
    fi
}

# 检查并记录操作是否完成
check_and_record() {
    local log_file="$1"
    if [[ -f "$log_file" ]]; then
        return 1  # 已经完成
    else
        return 0  # 未完成
    fi
}

# 记录操作完成状态
record_completion() {
    local log_file="$1"
    touch "$log_file"
}

# 初始化并启动Zookeeper
start_zookeeper() {
    local log_file="$LOG_DIR/zookeeper_initialized.log"
    if [[ ! -f "$log_file" ]]; then
        echo "正在初始化Zookeeper myid..."
        mkdir -p /data/zookeeper
        echo $ZOO_MY_ID > /data/zookeeper/myid
        record_completion "$log_file"
    else
        echo "Zookeeper已经初始化，跳过此步骤。"
    fi

    if [[ ! -f $ZOOKEEPER_HOME/bin/zkServer.sh ]]; then
        echo "错误：Zookeeper启动脚本未找到。"
        exit 1
    fi
    echo "正在启动Zookeeper服务..."
    $ZOOKEEPER_HOME/bin/zkServer.sh start
    sleep 5
}

# 启动Hadoop的journalnode
start_journalnode() {
    local log_file="$LOG_DIR/journalnode_initialized.log"
    if [[ ! -f "$log_file" ]]; then
        echo "正在启动Hadoop journalnode..."
        $HADOOP_HOME/sbin/hadoop-daemon.sh start journalnode
        if [[ $? -ne 0 ]]; then
            echo "错误：启动journalnode失败。"
            exit 1
        fi
        record_completion "$log_file"
    else
        echo "Journalnode已经启动，跳过此步骤。"
    fi
}

# 初始化并启动HDFS Namenode
start_hadoop() {
    local log_file="$LOG_DIR/namenode_initialized.log"
    if [[ ! -f "$log_file" ]]; then
        echo "正在初始化HDFS Namenode..."
        $HADOOP_HOME/bin/hdfs namenode -format
        if [[ $? -ne 0 ]]; then
            echo "错误：格式化Namenode失败。"
            exit 1
        fi
        rsync -avz /data/hadoop/namenode docker-hadoop2:/data/hadoop
        $HADOOP_HOME/bin/hdfs zkfc -formatZK
        if [[ $? -ne 0 ]]; then
            echo "错误：格式化Zookeeper Failover Controller失败。"
            exit 1
        fi
        record_completion "$log_file"
    else
        echo "HDFS Namenode已经初始化，跳过此步骤。"
    fi

    echo "正在启动Hadoop服务..."
    $HADOOP_HOME/sbin/start-dfs.sh
    if [[ $? -ne 0 ]]; then
        echo "错误：启动HDFS失败。"
        exit 1
    fi
    $HADOOP_HOME/sbin/start-yarn.sh
    if [[ $? -ne 0 ]]; then
        echo "错误：启动YARN失败。"
        exit 1
    fi
}

# 停止服务并清理
stop() {
    echo "收到停止信号，正在停止进程并清理资源..."
    # 停止Hadoop相关服务（如果是主节点）
    if [[ $HADOOP_MASTER -eq 1 ]]; then
        echo "正在停止Hbase相关服务..."
        $HBASE_HOME/bin/stop-hbase.sh || echo "警告：停止Hbase失败，请检查日志。"
        echo "正在停止Hadoop主节点服务..."
        $HADOOP_HOME/sbin/stop-yarn.sh || echo "警告：停止YARN失败，请检查日志。"
        $HADOOP_HOME/sbin/stop-dfs.sh || echo "警告：停止HDFS失败，请检查日志。"
    fi

    # 停止Zookeeper服务
    echo "正在停止Zookeeper服务..."
    $ZOOKEEPER_HOME/bin/zkServer.sh stop || echo "警告：停止Zookeeper失败，请检查日志。"

    # 清理临时文件
    echo "正在清理临时文件..."
    rm -rf /tmp/hadoop-*
    echo "所有服务已停止，退出脚本..."
}


# 启动hbase
start_hbase(){
  $HBASE_HOME/bin/start-hbase.sh
}


# 全局变量
LOG_DIR="/var/log/docker_setup"
container=("docker-hadoop1" "docker-hadoop2" "docker-hadoop3")
SSH_PASSWORD="20020725"

# 初始化脚本
main() {
    # 捕捉退出信号
    trap stop SIGTERM
    mkdir -p $LOG_DIR
    start_ssh  # 启动SSH并复制SSH密钥

    if [[ ! -d /opt ]]; then
        echo "错误：/opt目录不存在。"
        exit 1
    fi
    ls -a /opt

    if [[ -z $ZOO_MY_ID ]]; then
        echo "错误：ZOO_MY_ID没有设置。"
        exit 1
    fi

    start_zookeeper  # 启动并初始化Zookeeper
    start_journalnode  # 启动日志节点

    sleep 5
    if [[ $HADOOP_MASTER -eq 1 ]]; then
        start_hadoop  # 启动Hadoop服务
        start_hbase # 启动hbase服务
    fi
    sleep infinity
}

main
