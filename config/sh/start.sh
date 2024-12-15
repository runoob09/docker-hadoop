#!/bin/bash

# 启动SSH服务
start_ssh() {
    echo "Starting SSH service..."
    service ssh start
    sleep 10
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

# 复制SSH密钥到容器
copy_ssh_keys() {
    local log_file="$LOG_DIR/ssh_key_copied.log"
    check_and_record "$log_file"
    if [[ $? -eq 0 ]]; then
        echo "Copying SSH keys to containers..."
        for host in "${container[@]}"; do
            echo "Copying SSH key to $host..."
            sshpass -p "$SSH_PASSWORD" ssh-copy-id -o StrictHostKeyChecking=no root@"$host"
        done
        record_completion "$log_file"
    else
        echo "SSH keys already copied. Skipping."
    fi
}

# 初始化Zookeeper的myid
initialize_zookeeper() {
    local log_file="$LOG_DIR/zookeeper_initialized.log"
    check_and_record "$log_file"
    if [[ $? -eq 0 ]]; then
        echo "Initializing Zookeeper myid..."
        mkdir -p /data/zookeeper
        echo $ZOO_MY_ID > /data/zookeeper/myid
        record_completion "$log_file"
    else
        echo "Zookeeper already initialized. Skipping."
    fi
}
# 启动zookeeper
start_zookeeper() {
  if [[ ! -f $ZOOKEEPER_HOME/bin/zkServer.sh ]]; then
            echo "Error: Zookeeper start script not found."
            exit 1
        fi
        $ZOOKEEPER_HOME/bin/zkServer.sh start
        sleep 5
}
# 启动日志节点
start_journalnode() {
    local log_file="$LOG_DIR/journalnode_initialized.log"
    check_and_record "$log_file"
    if [[ $? -eq 0 ]]; then
        echo "Starting Hadoop journalnode..."
        $HADOOP_HOME/sbin/hadoop-daemon.sh start journalnode
        if [[ $? -ne 0 ]]; then
            echo "Error: Failed to start journalnode."
            exit 1
        fi
        record_completion "$log_file"
    else
        echo "Journalnode already initialized. Skipping."
    fi
}

# 初始化HDFS Namenode
initialize_hadoop() {
    local log_file="$LOG_DIR/namenode_initialized.log"
    check_and_record "$log_file"
    if [[ $? -eq 0 ]]; then
        echo "Initializing HDFS namenode..."
        $HADOOP_HOME/bin/hdfs namenode -format
        if [[ $? -ne 0 ]]; then
            echo "Error: Failed to format namenode."
            exit 1
        fi
        rsync -avz /data/hadoop/namenode docker-hadoop2:/data/hadoop
        $HADOOP_HOME/bin/hdfs zkfc -formatZK
        if [[ $? -ne 0 ]]; then
            echo "Error: Failed to format Zookeeper Failover Controller."
            exit 1
        fi
        record_completion "$log_file"
    else
        echo "HDFS namenode already initialized. Skipping."
    fi
}

# 启动Hadoop服务
start_hadoop() {
    echo "Starting Hadoop services..."
    $HADOOP_HOME/sbin/start-dfs.sh
    if [[ $? -ne 0 ]]; then
        echo "Error: Failed to start HDFS."
        exit 1
    fi
    $HADOOP_HOME/sbin/start-yarn.sh
    if [[ $? -ne 0 ]]; then
        echo "Error: Failed to start YARN."
        exit 1
    fi
}
# 停止函数
stop() {
    echo "Received stop signal. Stopping processes and cleaning up resources..."

    # 检查是否是 Hadoop 主节点
    if [[ $HADOOP_MASTER -eq 1 ]]; then
        echo "Stopping Hadoop services on master node..."
        if $HADOOP_HOME/sbin/stop-yarn.sh; then
            echo "Successfully stopped YARN."
        else
            echo "Warning: Failed to stop YARN. Please check logs."
        fi

        if $HADOOP_HOME/sbin/stop-dfs.sh; then
            echo "Successfully stopped HDFS."
        else
            echo "Warning: Failed to stop HDFS. Please check logs."
        fi
    fi

    # 停止 Zookeeper 服务
    echo "Stopping Zookeeper service..."
    if $ZOOKEEPER_HOME/bin/zkServer.sh stop; then
        echo "Successfully stopped Zookeeper."
    else
        echo "Warning: Failed to stop Zookeeper. Please check logs."
    fi

    # 检查并清理残留的临时文件或资源
    echo "Cleaning up temporary files and resources..."
    rm -rf /tmp/hadoop-*
    echo "All services stopped. Exiting..."
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
    start_ssh
    copy_ssh_keys

    if [[ ! -d /opt ]]; then
        echo "Error: /opt directory does not exist."
        exit 1
    fi
    ls -a /opt

    if [[ -z $ZOO_MY_ID ]]; then
        echo "Error: ZOO_MY_ID is not set."
        exit 1
    fi
    initialize_zookeeper # 初始化zookeeper
    start_zookeeper # 启动zookeeper
    start_journalnode # 启动日志节点

    sleep 5
    if [[ $HADOOP_MASTER -eq 1 ]]; then
        initialize_hadoop
        sleep 5
        start_hadoop
    fi
    sleep infinity
}
main
