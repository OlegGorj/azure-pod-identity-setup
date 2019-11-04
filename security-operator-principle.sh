#!/usr/bin/env bash

app_name="app1"
vaultRG="kv-test"
clusterRG="DefaultResourceGroup-CUS"
cluster="operator-test-cluster"
namespace="${app_name}-ns"
principal="${app_name}-principal"

az account set -s ""

az aks get-credentials --name $cluster --resource-group $clusterRG
kubectl apply -f https://raw.githubusercontent.com/Azure/aad-pod-identity/master/deploy/infra/deployment-rbac.yaml

# Create an Azure Identity
identityJson=$(az identity create -g $clusterRG -n $principal --query "{ClientId: clientId, ManagedIdentityId: id, TenantId:  tenantId}" -o jsonc)
identityJson=$(az identity show -g $clusterRG -n $principal)
tenantId=$(echo $identityJson | jq '.tenantId')
clientId=$(echo $identityJson | jq '.clientId')
scope=$(echo $identityJson | jq '.id')


# assign the Service Principal running the cluster the Managed Identity Operator role on the user managed identity:
#az aks show -g $clusterRG -n $cluster --query "servicePrincipalProfile.clientId" -o tsv
aksPrincipalId=$(az aks show -g $clusterRG -n $cluster --query "servicePrincipalProfile.clientId" -o tsv)
managedId=$(az identity show -g $clusterRG -n $principal --query "id" -o tsv)

assignmentJSON=$(az role assignment create --role "Managed Identity Operator" --assignee $aksPrincipalId --scope $managedId)
az role assignment list --scope $managedId


# Create app namespace
kubectl create namespace $namespace
kubectl label namespace/$namespace description=PodIdentity PodIdentity=true

# modify identity.yaml to include params from step "Create an Azure Identity"
kubectl apply -f identity.yaml --namespace $namespace
kubectl apply -f binding.yaml --namespace $namespace
kubectl get AzureIdentityBinding --namespace $namespace

# create the Azure AD application corresponding to the $app_name
appId=$(az ad app create --display-name $app_name --identifier-uris http://app1.aad-pod-identity --query "appId" -o tsv)
echo $appId
az ad app list  --app-id $appId

kubectl apply -f service.yaml --namespace $namespace
kubectl apply -f client-pod.yaml --namespace $namespace
kubectl get AzureAssignedIdentity --all-namespaces




# Create a service principal and configure its access to Azure resources with a self-signed certificate for authentication
# az ad sp create-for-rbac --name TestServicePrincipal --create-cert --role contributor
az ad sp create-for-rbac --name ServicePrincipalName --create-cert --role contributor --cert CertName --keyvault VaultName

# get the app id of the service principal
servicePrincipalAppId=$(az ad sp list --display-name $appId --query "[].appId" -o tsv)

# get the id of that default assignment
roleId=$(az role assignment list --assignee $servicePrincipalAppId --query "[].id" -o tsv)

# delete that role assignment
az role assignment delete --ids $roleId

# get our subscriptionId
subscriptionId=$(az account show --query id -o tsv)

# grant contributor access just to this resource group only
az role assignment create --assignee $servicePrincipalAppId \
        --role "contributor" \
        --scope "/subscriptions/$subscriptionId/resourceGroups/$resourceGroup"

# n.b to see this assignment in the output of az role assignment list, you neeed the --all flag:
az role assignment list --assignee $servicePrincipalAppId --all


# To sign in with the principal
az login --service-principal --username APP_ID --tenant TENANT_ID --password /path/to/cert
