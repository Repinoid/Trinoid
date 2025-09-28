#!/bin/sh
set -e

# Установка classpath из hadoop command
echo "Setting up Hadoop and Hive classpath..."
export POSTGRESQL_DRIVER_PATH="/opt/hive/lib/postgresql-42.7.8.jar"
export HADOOP_CLASSPATH=$(/opt/hadoop/bin/hadoop classpath --glob):/opt/hive/lib/*
export CLASSPATH=$HADOOP_CLASSPATH
export HADOOP_HOME=/opt/hadoop

# Создаем директорию если не существует

if [ ! -d "/home/hive" ]; then
    echo "Creating /home/hive directory..."
    mkdir -p /home/hive
    chown hive:hive /home/hive
    chmod 755 /home/hive
fi

# Запускаем Hive Metastore сервис
echo "Starting Hive Metastore service on port 9083..."
exec /opt/hive/bin/hive --service metastore -p 9083
