#!/bin/bash

oadm new-project logging

CA=/etc/origin/master
sudo oadm ca create-server-cert --signer-cert=$CA/ca.crt \
   --signer-key=$CA/ca.key --signer-serial=$CA/ca.serial.txt \
   --hostnames='logging.apps.rhsademo.net' \
   --cert=logging.crt --key=logging.key

sudo chown ec2-user:ec2-user logging.{crt,key}

oc project logging

oc secrets new logging-deployer \
   kibana.crt=logging.crt kibana.key=logging.key

oc create -f - <<API
apiVersion: v1
kind: ServiceAccount
metadata:
  name: logging-deployer
secrets:
- name: logging-deployer
API

oc policy add-role-to-user edit \
            system:serviceaccount:logging:logging-deployer

oadm policy add-scc-to-user privileged system:serviceaccount:logging:aggregated-logging-fluentd

oadm policy add-cluster-role-to-user cluster-reader \
              system:serviceaccount:logging:aggregated-logging-fluentd

# oc create -n openshift -f /usr/share/openshift/examples/infrastructure-templates/enterprise/logging-deployer.yaml

oc process logging-deployer-template -n openshift \
           -v KIBANA_HOSTNAME=logging.apps.rhsademo.net,ES_CLUSTER_SIZE=1,PUBLIC_MASTER_URL=https://master.rhsademo.net:8443,ES_OPS_CLUSTER_SIZE=1,KIBANA_OPS_HOSTNAME=logging-ops.apps.rhsademo.net,ENABLE_OPS_CLUSTER=true \
           | oc create -f -


