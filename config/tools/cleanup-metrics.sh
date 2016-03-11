#!/bin/bash

oc delete all --all -n openshift-infra --grace-period=0

oc delete pvc --all -n openshift-infra 
oc delete templates --all -n openshift-infra

oc delete sa cassandra hawkular heapster metrics-deployer
oc delete secrets hawkular-cassandra-certificate hawkular-cassandra-secrets hawkular-metrics-account hawkular-metrics-certificate hawkular-metrics-secrets heapster-secrets metrics-deployer  metrics-deployer-dockercfg-yq3g6 metrics-deployer-token-3k1of metrics-deployer-token-4reth metrics-deployer-token-mb3ew 

