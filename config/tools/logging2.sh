#!/bin/bash

# Run after the initial logging definition is done

oc process logging-support-template | oc create -f -

DC=$(oc get dc --selector logging-infra=elasticsearch --no-headers | awk '{print $1;}')
oc volume dc/$DC --add --name=elasticsearch-storage -t pvc --claim-size=20G --overwrite

