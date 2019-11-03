#!/usr/bin/env bash

app_name="security-operator"
clusterRG="DefaultResourceGroup-CUS"
cluster="operator-test-cluster"
namespace="${app_name}-ns"
principal="${app_name}-principal"
binding="${app_name}-principal-binding"
podSelector="pod-selector-label"
azAccount="...."

vaultName="test-vault-2b"

az account set -s "$azAccount"

az aks get-credentials --name $cluster --resource-group $clusterRG

identityPrincipalId=$(az identity show -g $clusterRG -n $principal | jq '.principalId')

az keyvault set-policy --name $vaultName --object-id $identityPrincipalId --secret-permissions get list
