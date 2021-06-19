#!/bin/bash

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

upload() {
  $curl -d "$body" -X POST \
    -H "Content-Type: application/json" \
    --oauth2-bearer $( echo $tokens | jq -r .access_token ) \
    "https://${TOWER_HOST}/api/v2/credentials/"
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
if [ $? -eq 0 ]
then
  echo "Success"
else
  echo "Fail: $output"
fi

