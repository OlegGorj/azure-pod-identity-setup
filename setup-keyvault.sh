#!/usr/bin/env bash -x

source ./vars.sh

az account set -s "$azAccount"

# create tag for $appName
#az tag create --name $appCode  --subscription $azAccount
#az tag add-value --name $appCode --value $appName --subscription $azAccount

kvJson=$(az keyvault create --name $keyvaultName --resource-group $keyvaultRG) && echo "KeyVault created:" && echo $kvJson | jq -r '.id'

secretJson=$(az keyvault secret set --vault-name $keyvaultName --name secret1 --value "Don't tell anyone this is secret 1") && echo "Creating secret: id:" && echo $secretJson | jq '.id'

tagsJson=$(az resource tag --tags appcode=$appCode appname=$appName --resource-group $keyvaultRG --name $keyvaultName --resource-type "Microsoft.KeyVault/vaults") && echo "Tagging: provisioningState:" && echo $tagsJson | jq '.properties.provisioningState'
