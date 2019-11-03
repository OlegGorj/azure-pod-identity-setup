#!/usr/bin/env bash

app_name="app1"
vaultRG="kv-test"
clusterRG="DefaultResourceGroup-CUS"
cluster="operator-test-cluster"
namespace="${app_name}-d-ns"
principal="${app_name}-principal"
binding="${app_name}-principal-binding"
podSelector="pod-selector-label"
azAccount=".."

az account set -s "$azAccount"

az aks get-credentials --name $cluster --resource-group $clusterRG

echo "Creating Identity.."
identityJson=$(az identity create -g $clusterRG -n $principal --query "{ClientId: clientId, ManagedIdentityId: id, TenantId:  tenantId}" -o jsonc)

identityJson=$(az identity show -g $clusterRG -n $principal)
tenantId=$(echo $identityJson | jq '.tenantId') && echo "Identity TenantId: $tenantId"
clientId=$(echo $identityJson | jq '.clientId') && echo "Identity ClientId: $clientId"
scope=$(echo $identityJson | jq '.id') && echo "Identity Scope: $scope"

aksPrincipalId=$(az aks show -g $clusterRG -n $cluster --query "servicePrincipalProfile.clientId" -o tsv) && echo "AKS PrincipalId: $aksPrincipalId"
managedId=$(az identity show -g $clusterRG -n $principal --query "id" -o tsv) && echo "AKS Identity ID: $managedId"
assignmentJSON=$(az role assignment create --role "Managed Identity Operator" --assignee $aksPrincipalId --scope $managedId)
echo "assignmentJSON: $assignmentJSON"
#az role assignment list --scope $managedId

sed -e "
s|{{ .AppPrincipalName }}|${principal}|g
s|{{ .ResourceID }}|${scope}|g
s|{{ .ClientID }}|${clientId}|g
" identity.template.yaml > identity.yaml

sed -e "
s|{{ .AppPrincipalBinding }}|${binding}|g
s|{{ .AppPrincipalName }}|${principal}|g
s|{{ .PodSelectorLabel }}|${podSelector}|g
" binding.template.yaml > binding.yaml


kubectl create namespace $namespace
kubectl label namespace/$namespace description=PodIdentity PodIdentity=true

kubectl apply -f identity.yaml --namespace $namespace
kubectl apply -f binding.yaml --namespace $namespace
kubectl get AzureIdentityBinding --namespace $namespace

appId=$(az ad app create --display-name $app_name --identifier-uris http://app1.aad-pod-identity --query "appId" -o tsv)
echo $appId
az ad app list  --app-id $appId

sed -e "
s|{{ .ResourceId }}|${appId}|g
s|{{ .PodSelectorLabel }}|${podSelector}|g
" client-pod.template.yaml > client-pod.yaml

kubectl apply -f client-pod.yaml --namespace $namespace

echo "AzureAssignedIdentity's across all NSs: " && kubectl get AzureAssignedIdentity --all-namespaces
