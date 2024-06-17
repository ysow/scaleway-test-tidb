#!/bin/ash

echo "Preparing..."
sysbench --config-file=config --threads=16 oltp_insert_ignore --tables=1 --table_size=1 prepare

echo "Running..."
sysbench --config-file=config --threads=16 oltp_insert_ignore --tables=1 --table_size=1 run
