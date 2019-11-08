#!/usr/bin/env bash

appName="application1"
appCode="AC0001"
azAccount="..."
clusterRG="DefaultResourceGroup-CUS"
clusterName="operator-test-cluster"

#podSelector="pod-selector-label"
registryName="securityopregistrytest"
registryRG=$clusterRG
#reponame="env_injector"

keyvaultName="az-keyvault-${appName}"
keyvaultTag="az-keyvault-tag-${appCode}"
keyvaultRG=$clusterRG

namespace="${appName}-d-ns"
principal="${appName}-principal"
binding="${appName}-principal-binding"
az account set -s "$azAccount"

# create tag for $appName
#az tag create --name $appCode  --subscription $azAccount
#az tag add-value --name $appCode --value $appName --subscription $azAccount

kvJson=$(az keyvault create --name $keyvaultName --resource-group $keyvaultRG) && echo "KeyVault created:" && echo $kvJson | jq '.id'
tagsJson=$(az resource tag --tags appcode=$appCode appname=$appName --resource-group $keyvaultRG --name $keyvaultName --resource-type "Microsoft.KeyVault/vaults") && echo "Tagging: provisioningState:" && echo $tagsJson | jq '.properties.provisioningState'


##
# Cleanup
##
az keyvault delete --name $keyvaultName  --resource-group $keyvaultRG
