#!/bin/bash

oc delete all -l docker-registry

sudo oadm registry --config=/etc/origin/master/admin.kubeconfig \
   --credentials=/etc/origin/master/openshift-registry.kubeconfig \
   --images='registry.access.redhat.com/openshift3/ose-${component}:${version}' \
   --selector="region=infra"

exit 0

oc volume deploymentconfigs/docker-registry \
     --add --overwrite --name=registry-storage --mount-path=/registry \
     --source='{"nfs": { "server": "ip-10-0-0-48.ec2.internal", "path": "/mnt/nfs/registry"}}'

