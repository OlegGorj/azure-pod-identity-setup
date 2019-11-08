#!/usr/bin/env bash -x

source ./vars.sh

az account set -s "$azAccount"

##
# Cleanup
##

az keyvault delete --name $keyvaultName  --resource-group $keyvaultRG
