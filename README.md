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

Find deployed services external IPs

```
kubectl get svc -n tidb-cluster | grep LoadBalancer
```

For example, the dashboard is accessible via `http://<external-ip>:12333`

What is deployed
----------------

- TiDB cluster with:
  - pd replicas: 3
  - tikv replicas: 3 (with 100GiB each of storage 15k IOPS)
  - tiflash replicas: 2 (with 100GiB each of storage 15k IOPS)
  - tidb replicas: 2 (with a LoadBalancer service)
  - ticdc replicas: 2
- TiDB dasboard (with a LoadBalancer service and 10Gi of storage 5k IOPS)
- TiDB monitor (with a LoadBalancer service for grafana with 20Gi of storage 5k IOPS)
- TiDB NGmonitor (with 20 Gi of storage 5k IOPS)

Root password for the database is initialized to `ChangeMe123!`

Grafana user/pass is `monit` with `ChangeMe123!`

Benchmark
---------

A simple benchmark can be run in the K8s cluster using provided image (see `tidb-bench` folder)

```
kubectl apply -f tidb-bench-job.yaml
kubectl wait -n tidb-cluster --for=condition=complete --timeout=360s job/tidb-bench
kubectl logs -n tidb-cluster --tail=26 -l=job-name=tidb-bench
```

Sample results:

```
SQL statistics:
    queries performed:
        read:                            0
        write:                           273386
        other:                           0
        total:                           273386
    transactions:                        273386 (911.25 per sec.)
    queries:                             273386 (911.25 per sec.)
    ignored errors:                      0      (0.00 per sec.)
    reconnects:                          0      (0.00 per sec.)

General statistics:
    total time:                          300.0117s
    total number of events:              273386

Latency (ms):
         min:                                    8.05
         avg:                                   17.55
         max:                                  494.11
         95th percentile:                       23.52
         sum:                              4798856.77

Threads fairness:
    events (avg/stddev):           17086.6250/25.93
    execution time (avg/stddev):   299.9285/0.01
```

TODO
----

All services are exposed without SSL. The dashboard and grafana would be better exposed through an Ingress leveraging Certmanager.

The TiDB service could be exposed only in the VPC using an internal LoadBalancer and should be configured with SSL using Certmanager for example: [Docs](https://docs.pingcap.com/tidb-in-kubernetes/stable/enable-tls-for-mysql-client#using-cert-manager)

The inter-component component communication is not using SSL either, this can also be configured using Certmanager: [Docs](https://docs.pingcap.com/tidb-in-kubernetes/stable/enable-tls-between-components#using-cert-manager)
