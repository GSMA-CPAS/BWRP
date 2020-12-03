#!/bin/bash
. setup.cfg

file=deployment/config/ccp/${CFG_ORG}.json.tpl
cp deployment/config/ccp/ORG.json.tpl $file

sed -i "s/\${ORG}/${CFG_ORG}/g" $file
sed -i "s/\${HOSTNAME}/${CFG_HOSTNAME}/g" $file
sed -i "s/\${PEER_NAME}/${CFG_PEER_NAME}/g" $file
sed -i "s/\${DOMAIN}/${CFG_DOMAIN}/g" $file
sed -i "s/\${PEER_PORT}/${CFG_PEER_PORT}/g" $file
sed -i "s/\${CHAINCODE_NAME}/${CFG_CHAINCODE_NAME}/g" $file
sed -i "s/\${CHANNEL_NAME}/${CFG_CHANNEL_NAME}/g" $file

for file in $(ls $CFG_CONFIG_PATH/config/ccp/${CFG_ORG}.json.tpl); do
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
            sed -e "s/\(.*\)\(from_pem:\s*[^ \"]*\)\(.*\)/\1$PEM\3/" <<< "$line" >> $OUTPUT
        else
            
            # nothing to do
            echo $line >> $OUTPUT
        fi;
    done < "$file"
done

for file in $(ls $CFG_CONFIG_PATH/config/ccp/wallet/*.tpl); do
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
            sed -e "s/\(.*\)\(from_pem:\s*[^ \"]*\)\(.*\)/\1$PEM\3/" <<< "$line" >> $OUTPUT
        else
            
            # nothing to do
            echo $line >> $OUTPUT
        fi;
    done < "$file"
done

