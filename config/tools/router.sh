#!/bin/bash

sudo oadm router --service-account=router \
    --credentials='/etc/origin/master/openshift-router.kubeconfig' \
    --selector="region=infra"

