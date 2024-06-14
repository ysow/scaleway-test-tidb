#!/bin/sh
echo "Create CRD"
kubectl create -f https://raw.githubusercontent.com/pingcap/tidb-operator/v1.6.0/manifests/crd.yaml

echo "Add operator"
helm repo add pingcap https://charts.pingcap.org/
helm repo update
helm upgrade --install --namespace tidb-admin --create-namespace tidb-operator pingcap/tidb-operator --version v1.6.0

echo "Create cluster"
kubectl -n tidb-cluster apply -f tidb-cluster.yaml

