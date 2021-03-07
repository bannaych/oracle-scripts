# Oracle single instance with Pure ActiveCluster Sync Replication

In this blog I will show you how we can configure an Oracle single database with ActiveCluster replication. The configuration uses a two POD design
where protection group snapshots from the primary POD are used to create clone database volumes in a seconday POD. The DR database then used the volume in the
secondary POD mitigating any risk on concurrent disk access from the Primary POD. The DR server can then be refreshed at any point in time using the snapshots from the primary POD. Because the primary POD is replicated synchrnously, the DR server will always be upto date. Ie if we have an outage on PROD, the refresh on the DR server will be the last committed write on the Primay POD





# Environment
```
# kubectl get nodes -o wide
NAME      STATUS   ROLES    AGE    VERSION   INTERNAL-IP       EXTERNAL-IP   OS-IMAGE             KERNEL-VERSION      CONTAINER-RUNTIME
master    Ready    master   4d4h   v1.18.2   192.168.111.231   <none>        Ubuntu 18.04.1 LTS   4.15.0-29-generic   docker://19.3.6
worker1   Ready    <none>   4d4h   v1.18.2   192.168.111.232   <none>        Ubuntu 18.04.1 LTS   4.15.0-99-generic   docker://19.3.6
