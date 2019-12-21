#!/usr/bin/env bash
source ./vars.sh

az account set -s "$azAccount"

az aks get-credentials --name $clusterName --resource-group $clusterRG

# super important
kubectl apply -f https://raw.githubusercontent.com/Azure/aad-pod-identity/master/deploy/infra/deployment-rbac.yaml

subscriptionId=$(az account show --query "id") && subscriptionId=$(sed -e 's/^"//' -e 's/"$//' <<<$subscriptionId)
subscriptionScope="/subscriptions/$subscriptionId"
clusterRGScope=$(az group show --name  $clusterRG --query "id") && clusterRGScope=$(sed -e 's/^"//' -e 's/"$//' <<<$clusterRGScope)

# Identity
echo "Creating Identity.."
identJson=$(az identity create -g $clusterRG -n $principal -o json)
identityJson=$(az identity show -g $clusterRG -n $principal -o json)
identityPrincipalId=$(echo $identityJson | jq -r '.principalId') && echo "Identity PrincipalId: $identityPrincipalId"
identityScope=$(echo $identityJson | jq -r '.id') && echo "Identity Scope: $identityScope"
clientId=$(echo $identityJson | jq -r '.clientId') && echo "Identity ClientId: $clientId"

sleep 15

# assign identity to Cluster RG
roleAssignJson=$(az role assignment create --role Reader --assignee $identityPrincipalId --scope $clusterRGScope)
# identityJson=$(az identity create -g $clusterRG -n $principal --query "{ClientId: clientId, ManagedIdentityId: id, TenantId:  tenantId}" -o jsonc)

# Vault vars
keyvaultRGScope=$(sed -e 's/^"//' -e 's/"$//' <<<$(az group show --name  $keyvaultRG --query "id"))
# assign identity to Vault RG
roleAssignJson=$(az role assignment create --role Reader --assignee $identityPrincipalId --scope $keyvaultRGScope)
# set policy to access vault
roleAssignJson=$(az keyvault set-policy --name $keyvaultName --object-id $identityPrincipalId --secret-permissions get list)

# AKS vars
aksPrincipalId=$(sed -e 's/^"//' -e 's/"$//' <<<$(az aks show -g $clusterRG -n $clusterName --query  "servicePrincipalProfile.clientId" -o tsv)) && echo "AKS Service Principal: $aksPrincipalId"
# assign AKS service principal to identity
roleAssignJson=$(az role assignment create --role "Managed Identity Operator" --assignee $aksPrincipalId --scope $identityScope)

#
# Make sure registry $registryname is created
#
# ACR vars
registryid=$(sed -e 's/^"//' -e 's/"$//' <<<$(az acr show --name $registryname --query id --output tsv))
# assign identity to ACR
roleAssignJson=$(az role assignment create --assignee $identityPrincipalId --scope $registryid --role acrpull)
roleAssignJson=$(az role assignment create --assignee $identityPrincipalId --scope $registryid --role Contributor)

roleAssignJson=$(az role assignment create --assignee $aksPrincipalId --scope $registryid --role acrpull)
roleAssignJson=$(az role assignment create --assignee $aksPrincipalId --scope $registryid --role Contributor)

# attach aks to acr
az extension add --name aks-preview
updateJson=$(az aks update --name $clusterName --resource-group $clusterRG --attach-acr $registryid)

#identityJson=$(az identity show -g $clusterRG -n $principal)
#tenantId=$(echo $identityJson | jq '.tenantId') && echo "Identity TenantId: $tenantId"
#clientId=$(echo $identityJson | jq '.clientId') && echo "Identity ClientId: $clientId"
#principalId=$(echo $identityJson | jq '.principalId')  && echo "Identity PrincipalId: $principalId"
#scope=$(echo $identityJson | jq '.id') && echo "Identity Scope: $scope"
#managedId=$(az identity show -g $clusterRG -n $principal --query "id" -o tsv) && echo "Identity ID: $managedId"

# Link Identity to AKS
#assignmentJSON=$(az role assignment create --role "Managed Identity Operator" --assignee $aksPrincipalId --scope $managedId)
#echo "assignmentJSON: $assignmentJSON"

# vault
#az role assignment create --role Reader --assignee <principalid> --scope /subscriptions/<subscriptionid>/resourcegroups/<resourcegroup>/providers/Microsoft.KeyVault/vaults/<keyvaultname>
# set policy to access keys in your Key Vault
#az keyvault set-policy -n $KV_NAME --key-permissions get --spn <YOUR AZURE USER IDENTITY CLIENT ID>
# set policy to access secrets in your Key Vault
#az keyvault set-policy -n $KV_NAME --secret-permissions get --spn <YOUR AZURE USER IDENTITY CLIENT ID>
# set policy to access certs in your Key Vault
#az keyvault set-policy -n $KV_NAME --certificate-permissions get --spn <YOUR AZURE USER IDENTITY CLIENT ID>

sed -e "
s|{{ .AppPrincipalName }}|${principal}|g
s|{{ .ResourceID }}|${identityScope}|g
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
kubectl get AzureIdentityBinding --all-namespaces

# Test part
appId=$(az ad app create --display-name $app_name --identifier-uris http://${app_name}.aad-pod-identity --query "appId" -o tsv)
appId=$(az ad app list --display-name $app_name | jq -r '.[].appId')
az ad app list --app-id $appId

sed -e "
s|{{ .ResourceId }}|${appId}|g
s|{{ .PodSelectorLabel }}|${podSelector}|g
" client-pod.template.yaml > client-pod.yaml

kubectl apply -f client-pod.yaml --namespace $namespace

echo "AzureAssignedIdentity's across all NSs: " && kubectl get AzureAssignedIdentity --all-namespaces
