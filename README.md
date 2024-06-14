tidb@scaleway
=============

Test of deploying TiDB on a Kapsule cluster using the TiDB operator and Scaleway Block Storage low latency 15k.

pre-requisites
--------------

- Helm and kubectl CLI installed
- Kapsule cluster with:
  - Some standard nodes for traditional workloads (3 PRO2-S is ideal to handle cpu requests from TiDB/PD and TiCDC)
  - 5 dedicated storage nodes (PRO2-XXS are enough):
    - pool name: `storage`
    - pool tag: `taint=node=storage:NoSchedule`

TiKV and TiFlash pods will be deployed on the storage nodes, with 100GiB PVC.

usage
-----

Run the shell script to `install.sh` all in one go or:

Install the needed CRD
```
kubectl create -f https://raw.githubusercontent.com/pingcap/tidb-operator/v1.6.0/manifests/crd.yaml
```

Add helm repo and install TiDB operator
```
helm repo add pingcap https://charts.pingcap.org/
helm repo update
helm upgrade --install --namespace tidb-admin --create-namespace tidb-operator pingcap/tidb-operator --version v1.6.0
```

Create the cluster with dasboard and monitoring
```
kubectl -n tidb-cluster apply -f tidb-cluster.yaml
```

