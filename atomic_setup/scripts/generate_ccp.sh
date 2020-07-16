#!/bin/bash
. setup.cfg

for file in $(ls $CFG_CONFIG_PATH/config/ccp/*.tpl); do
    echo "> scanning template $file and replacing pem import tags"
    OUTPUT=${file%.tpl}
    echo > $OUTPUT
    while IFS='' read -r line || [[ -n "$line" ]]; do
        fn=$(sed -n -e 's/.*from_pem:\s*\([^ "]*\).*/\1/p' <<< "$line")
        if [ ! -z "$fn" ]; then
            echo "> fetching PEM '$fn'"
            if [ ! -f "$fn" ]; then 
                echo "> ERROR: failed to read file '$fn'";
                exit 1;
            fi;
            # fetch pem and escape chars so that we can feed it into sed
            PEM=$(cat $fn |  awk 1 ORS='\\n' | sed -e 's/[\/&]/\\&/g')
            # do replacement
            sed -e "s/\(.*\)\(from_pem:\s*[^ \"]*\)\(.*\)/\1$PEM\3/" <<< "$line" > $OUTPUT
        else
            # nothing to do
            echo $line > $OUTPUT
        fi;
    done < "$file"
done



#CFG_TLSCA_CERT_ORDERER=$(cat $(dirname $0)/certs/gsma/orderer/tlsca.orderer.hldid.org-cert.pem | awk 1 ORS='\\n')
