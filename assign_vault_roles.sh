#!/usr/bin/env bash

source ./vars.sh

az account set -s "$azAccount"

#az aks get-credentials --name $clusterName --resource-group $clusterRG

# Get identity id
identityPrincipalId=$(az identity show -g $clusterRG -n $principal | jq -r '.principalId')
# assign get and list secrets to Identity Principal
roleAssignJson=$(az keyvault set-policy --name $keyvaultName --object-id $identityPrincipalId --secret-permissions get list) && echo "Set-policy Provisioning State: $(echo $roleAssignJson | jq -r '.properties.provisioningState')"
