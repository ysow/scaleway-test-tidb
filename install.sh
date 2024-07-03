#!/bin/bash
set -x
cd terraform 

terraform apply -auto-approve


cd ..
export KUBECONFIG=./terraform/kubeconfig.yaml

kubectl create -f https://raw.githubusercontent.com/pingcap/tidb-operator/v1.6.0/manifests/crd.yaml

kubectl get crd 

helm repo add pingcap https://charts.pingcap.org/
helm repo update
helm upgrade --install --namespace tidb-admin --create-namespace tidb-operator pingcap/tidb-operator --version v1.6.0

kubectl get po -n tidb-admin -l app.kubernetes.io/name=tidb-operator

# mkdir -p ${PWD}/tidb-cluster && \
# wget https://raw.githubusercontent.com/pingcap/tidb-operator/v1.6.0/examples/advanced/tidb-cluster.yaml 

# kubectl create namespace tidb-cluster

