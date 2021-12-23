#!/bin/bash
# Update helm repo f AKO version
helm repo add ako https://projects.registry.vmware.com/chartrepo/ako

helm repo update
# Get newest AKO APP Version
appVersion=$(helm search repo | grep ako/ako | grep -v operator | awk '{print $3}')

# Get Release number of current deployed chart
akoRelease=$(helm list -n avi-system | grep ako | awk '{print $1}')

# Delete existing helm release and install a new one
helm delete $akoRelease -n avi-system
helm install ako/ako --generate-name --version $appVersion -f values.yaml --namespace avi-system
