#!/bin/bash
path=$1

TMP=$(mktemp -p ~)
mv ${path}/* $TMP
while read line; do
    if [ "${line//END}" != "$line" ]; then
        txt="$txt$line\n"
        # extract common name
        cn=$(echo -ne "$txt" | openssl x509 -noout -subject -nameopt multiline | sed -n 's/ *commonName *= //p')
        # remove trailing and leading whitespaces and replace spaces by _
        filename=$(echo "$cn" | awk '{$1=$1};1' | tr " " "_")
        output="${path}/${filename}-cert.pem"
        # export each file seperately
        echo "> exporting $cn to $output"
        echo -ne "$txt" > $output
        txt=""
    else
        txt="$txt$line\n"
    fi
done < $TMP
rm -rf $TMP