#!/bin/bash
echo $ZOO_MY_ID > /data/zookeeper/myid
zkServer.sh start-foreground