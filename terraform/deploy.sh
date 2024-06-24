#!/bin/bash
set -x

cd terraform 

terraform apply -auto-approve


export KUBECONFIG=./kubeconfig.yaml

kubectl create -f https://raw.githubusercontent.com/pingcap/tidb-operator/v1.6.0/manifests/crd.yaml

kubectl get crd 


# kubectl create ns tidb-admin


# helm pull pingcap/tidb-operator --untar 

helm install tidb-operator ./tidb-operator -n tidb-admin 

kubectl get po -n tidb-admin -l app.kubernetes.io/name=tidb-operator

# mkdir -p ${PWD}/tidb-cluster && \
# wget https://raw.githubusercontent.com/pingcap/tidb-operator/v1.6.0/examples/advanced/tidb-cluster.yaml 

kubectl create namespace tidb-cluster

#modify tidb cluster 

kubectl apply -f tidb-cluster/tidb-cluster.yaml 

kubectl get svc -n tidb-cluster | grep Loadbalancer

# brew install sysbench
export tidb_lb_ip="51.159.24.53"
export tidb_secret=ChangeMe123!

mysql -h $tidb_lb_ip -P 4000 -u root -p'ChangeMe123!' -e "CREATE DATABASE sbtest;"


sysbench --mysql-host=$tidb_lb_ip --mysql-port=4000 --mysql-user=root --mysql-password=$tidb_secret  --mysql-db=sbtest --db-driver=mysql oltp_read_write --tables=10 --table-size=1000000 prepare

tiup bench tpcc -H $tidb_lb_ip -P 4000 -U root -p $tidb_secret -D tpcc --warehouses 1000 prepare -T 32
tiup bench ch --host $tidb_lb_ip -P 4000  -U root -p $tidb_secret --warehouses 1000 run -D tpcc -T 50 -t 1 --time 1h
tiup bench ch -H $tidb_lb_ip -P 4000 -U root -p $tidb_secret  -D tpcc prepare

mysql -h $tidb_lb_ip -P 4000 -u root -p'ChangeMe123!' -e "ALTER DATABASE tpcc SET tiflash replica 2;"
mysql -h $tidb_lb_ip -P 4000 -u root -p'ChangeMe123!' -e "SELECT * FROM information_schema.tiflash_replica WHERE TABLE_SCHEMA = 'tpcc';"
tiup bench ch --host $tidb_lb_ip  -p $tidb_secret -P4000 --warehouses 1000 run -D tpcc -T 50 -t 1 --time 1h

tiup bench tpcc -H $tidb_lb_ip  -p $tidb_secret  -P 4000 -D tpcc --warehouses 100 check