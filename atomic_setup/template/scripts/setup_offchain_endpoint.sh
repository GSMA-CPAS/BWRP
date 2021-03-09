#!/bin/bash

  curl -X PUT http://${OFFCHAIN_COUCHDB_USER}:${OFFCHAIN_COUCHDB_PASSWORD}@offchain-couchdb-${HOSTNAME}:${OFFCHAIN_COUCHDB_TARGET_PORT}/_users
  curl -X PUT http://${OFFCHAIN_COUCHDB_USER}:${OFFCHAIN_COUCHDB_PASSWORD}@offchain-couchdb-${HOSTNAME}:${OFFCHAIN_COUCHDB_TARGET_PORT}/offchain_data

  for value in {1..5}
  do
    echo "try $value of 5: seting couchdb config:"
    curl -s -X PUT http://blockchain-adapter-${HOSTNAME}:${BLOCKCHAIN_ADAPTER_PORT}/config/offchain-db -d "{\"URI\": \"http://${OFFCHAIN_COUCHDB_USER}:${OFFCHAIN_COUCHDB_PASSWORD}@offchain-couchdb-${HOSTNAME}:${OFFCHAIN_COUCHDB_TARGET_PORT}\"}" -H "Content-Type: application/json"
    # read back to verify
    RESPONSE=$(curl -s http://blockchain-adapter-${HOSTNAME}:${BLOCKCHAIN_ADAPTER_PORT}/config/offchain-db)
    echo ""
    if echo $RESPONSE | grep -i "error" || [ -z "$RESPONSE" ]
    then
      echo "Error: failed to set endpoint, retrying..."
    else
      echo "Sucess"
      exit 0
    fi
    echo "will retry in 5s"
    sleep 5
  done
  echo "Failed to set up offchain db endpoint."
  exit 1
