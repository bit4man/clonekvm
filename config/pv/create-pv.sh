#!/bin/bash

for a in $(seq 1 20)
do
cat <<EOF  | oc create -f -
apiVersion: "v1"
kind: "PersistentVolume"
metadata:
  name: "pv${a}" 
spec:
  capacity:
    storage: "512Mi"
  accessModes:
    - "ReadWriteOnce" 
  nfs: 
    path: "/mnt/nfs/pv${a}" 
    server: "ip-10-0-0-48.ec2.internal"
  persistentVolumeReclaimPolicy: "Recycle"
EOF

for a in $(seq 21 30)
do
cat <<EOF  | oc create -f -
apiVersion: "v1"
kind: "PersistentVolume"
metadata:
  name: "pv${a}" 
spec:
  capacity:
    storage: "1Gi"
  accessModes:
    - "ReadWriteOnce" 
  nfs: 
    path: "/mnt/nfs/pv${a}" 
    server: "ip-10-0-0-48.ec2.internal"
  persistentVolumeReclaimPolicy: "Recycle"
EOF

done
