#!/bin/bash

# Upload a kubeconfig to tower.
# This script doesn't support multiple-contexts:
# $ rm ~/.kube/config
# $ az aks get-credentials --resource-group <group> --name <aks-cluster>

config="$( awk '{printf "%s\\n", $0}' ~/.kube/config )"
curl="curl -k -s "

auth() {
  $curl -X POST \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "grant_type=password&username=${TOWER_USER}&password=${TOWER_PASS}&scope=write" \
    -u "${TOWER_CLIENT_ID}:${TOWER_CLIENT_SECRET}" \
    https://${TOWER_HOST}/api/o/token/
}

get_type() {
  $curl -H "Content-Type: application/json" \
    --oauth2-bearer $( echo $tokens | jq -r .access_token ) \
    "https://${TOWER_HOST}/api/v2/credential_types/?search=kubeconfig" | jq -r '.results[0].id'
}

get_cred() {
  $curl -H "Content-Type: application/json" \
    --oauth2-bearer $( echo $tokens | jq -r .access_token ) \
    "https://${TOWER_HOST}/api/v2/credentials/?search=AKS-Kube-Config" | jq -r '.results[0].id'
}

upload() {
  cred_id=$(get_cred)
  if [ "$cred_id" == "null" ]
  then
    $curl -i -d "$body" -X POST \
      -H "Content-Type: application/json" \
      --oauth2-bearer $( echo $tokens | jq -r .access_token ) \
      "https://${TOWER_HOST}/api/v2/credentials/"
  else
    $curl -i -d "$body" -X PUT \
      -H "Content-Type: application/json" \
      --oauth2-bearer $( echo $tokens | jq -r .access_token ) \
      "https://${TOWER_HOST}/api/v2/credentials/${cred_id}/"
  fi
}

tokens=$(auth)
typeid=$(get_type)

read -r -d '' body <<EOF
{ 
  "name": "AKS-Kube-Config",
  "organization": 1,
  "type": "credential",
  "credential_type": $typeid,
  "inputs": { 
    "name": "aks-context",
    "kubeconfig": "$config"
  },
  "kind": "kubernetes"
}
EOF

output=$(upload)
result=$( echo "$output" | egrep "20[01] (Created|OK)" )
if [ "$result" ]
then
  echo "Success: $result"
else
  echo "Failed: $output"
fi

