#!/bin/bash

oc project openshift-infra

oc create -f - <<API
apiVersion: v1
kind: ServiceAccount
metadata:
  name: metrics-deployer
secrets:
- name: metrics-deployer
API

oadm policy add-role-to-user edit system:serviceaccount:openshift-infra:metrics-deployer
oadm policy add-cluster-role-to-user cluster-reader system:serviceaccount:openshift-infra:heapster

oc secrets new metrics-deployer nothing=/dev/null

if [ ! -r metrics-deployer.yaml ]; then
   cp /usr/share/ansible/openshift-ansible/roles/openshift_examples/files/examples/v1.1/infrastructure-templates/enterprise/metrics-deployer.yaml metrics-deployer.yaml
fi

oc process -f metrics-deployer.yaml -v HAWKULAR_METRICS_HOSTNAME=master.rhsademo.net | oc create -f -


