#!/usr/bin/env bash
app_name="app1"


app_code="AC0001"

clusterRG="secrets-operator-RG"
clusterName="secrets-operator-test-cluster"
namespace="${app_name}-ns"

principal="${app_name}-principal"
binding="${app_name}-principal-binding"

podSelector="pod-selector-label"

registryname="securityopregistrytest"
reponame="env_injector"

azAccount="...."

keyvaultName="az-keyvault-${app_name}"
keyvaultTag="az-keyvault-tag-${app_code}"
keyvaultRG=$clusterRG
