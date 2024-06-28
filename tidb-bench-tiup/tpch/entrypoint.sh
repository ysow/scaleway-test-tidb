#!/bin/bash
tidb_lb_ip=tidb-tidb
tidb_secret=ChangeMe123!

# echo "Preparing..."
# tiup bench tpcc -H $tidb_lb_ip -P 4000 -U root -p $tidb_secret --warehouses 4 --parts 4 prepare

# echo "running..."
# tiup bench tpcc -H $tidb_lb_ip -P 4000 -U root -p $tidb_secret --warehouses 4 --time 10m run
# echo "checking..."
# tiup bench tpcc -H $tidb_lb_ip -P 4000 -U root -p $tidb_secret --warehouses 4 check

tiup bench tpcc -H $tidb_lb_ip -P 4000 -U root -p $tidb_secret -D tpcc --warehouses 1000 prepare -T 32
tiup bench ch --host $tidb_lb_ip -P 4000  -U root -p $tidb_secret --warehouses 1000 run -D tpcc -T 50 -t 1 --time 1h
tiup bench ch -H $tidb_lb_ip -P 4000 -U root -p $tidb_secret  -D tpcc prepare

mysql -h $tidb_lb_ip -P 4000 -u root -p'ChangeMe123!' -e "ALTER DATABASE tpcc SET tiflash replica 2;"
mysql -h $tidb_lb_ip -P 4000 -u root -p'ChangeMe123!' -e "SELECT * FROM information_schema.tiflash_replica WHERE TABLE_SCHEMA = 'tpcc';"
tiup bench ch --host $tidb_lb_ip  -p $tidb_secret -P4000 --warehouses 1000 run -D tpcc -T 50 -t 1 --time 1h

tiup bench tpcc -H $tidb_lb_ip  -p $tidb_secret  -P 4000 -D tpcc --warehouses 1000 check