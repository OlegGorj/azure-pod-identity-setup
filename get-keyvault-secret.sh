#!/usr/bin/env bash

source ./vars.sh

vaultSecrets=("secret1")

# $(kubectl get pod --selector app=httpbin --output jsonpath='{.items[0].metadata.name}')
function get_token4vault {
  #scope=$1
  echo $(kubectl exec -n $namespace aad-id-client-pod -- curl 'http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https%3A%2F%2Fvault.azure.net' -H Metadata:true -s | awk -F"[{,\":}]" '{print $6}')
}

function fail {
  echo $1 >&2
  exit 1
}

echo "Setting up AZ account."
az account set -s "$azAccount"

echo "Retriving AKS credentials for cluster $cluster in resource group $clusterRG"
az aks get-credentials --name $cluster --resource-group $clusterRG

echo "Retriving Bearer token for the scope $tokenScopeVault ..."
n=1 && max=5 && delay=15
while true; do
  token_vault=$(get_token4vault $tokenScopeVault)
  [[ ! -z "$token_vault" ]] && break || {
    if [[ $n -lt $max ]]; then
      ((n++))
      echo "Retriving Bearer token failed. Attempt $n/$max:"
      echo "token_vault: $token_vault"
      sleep $delay;
    else
      fail "Retriving Bearer token has failed after $n attempts."
    fi
  }
done

if [ -z "$token_vault" ]
then
      echo "Couldn't retrive token for scope $tokenScopeVault"
      exit 1
else
      echo "Retriving secrets from vault $vaultName ..."
      for i in "${vaultSecrets[@]}"
      do
         echo "Using token: $token_vault"
         echo "Retriving Secret: $i"
         curl -s "https://$vaultName.vault.azure.net/secrets/$i?api-version=2016-10-01" -H "Authorization: Bearer $token_vault"
      done
fi

#curl -s "https://$vaultName.vault.azure.net/secrets/secret1?api-version=2016-10-01" -H "Authorization: Bearer $token_vault"
