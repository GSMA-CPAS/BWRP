#!/bin/bash
# abort processing on the first error
set -e -o pipefail

# load config
. setup.cfg

# process the templates:
./scripts/prepare_templates.sh setup.cfg ./$CFG_CONFIG_PATH

# check if we need to generate certificates
echo "> checking for ca certificates in $CFG_CONFIG_PATH_CA";
if [ -d $CFG_CONFIG_PATH_CA ]; then
    echo "> Existing Signed Intermediate Cert Exist."
    echo "  If you wish to regenerate a new one, please delete $CFG_CONFIG_PATH_CA"
else
    echo "> Not found! will generate and sign certs now. Request Username/Password for signing by mail."
    read -p "> Please enter Username:`echo $'\n> '`" registry_user
    read -p "> Please enter Password:`echo $'\n> '`" registry_pass
    ./scripts/generate_certificates.sh $registry_user $registry_pass
fi

# deploy CA and helper pods:
./scripts/deploy_ca.sh

# check if the CA is already set up or wen need to register/enroll the certificates
if [ -d $CFG_CONFIG_PATH_PVC/ca ]; then
    echo "> Backup of ca config found"
    ./scripts/upload_backup_to_ca.sh
else
    echo "> No backup of ca config found, generating crypto config"
    ./scripts/generate_crypto.sh
    ./scripts/generate_crypto_mtls.sh
fi;

./scripts/deploy_peer.sh

#prepare remote cli:
./scripts/prepare_remote_cli.sh

# deploy hybrid
./scripts/deploy_roamingonblockchain_repo_secrets.sh
./scripts/deploy_offchain_pods.sh
./scripts/generate_ccp_hybrid.sh
./scripts/deploy_blockchain_adapter.sh

# deploy frontend
./scripts/deploy_frontend.sh
