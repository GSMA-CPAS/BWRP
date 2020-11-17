#!/bin/bash
if [ $# -ne 2 ]; then 
    echo "> usage: $0 <setup.cfg> <output_path>"
    exit 1
fi

CONFIG=$1
OUTPUT=$2

source $CONFIG

# copy templates to output
# and replace all known variables
TMP=$(mktemp)
for file in template/kubernetes/webapp-svc.yaml template/kubernetes/webapp-pod.yaml template/kubernetes/webapp-nginx-cert.yaml template/kubernetes/webapp-nginx-pod.yaml template/kubernetes/webapp-nginx-svc.yaml ; do
	file="${file/"template/"/''}"
	IN=template/$file
	#ls -la  $IN
	OUT=$OUTPUT/$file
	mkdir -p $(dirname "$OUT")  
	cp -ar $IN $TMP
	
	echo "> generating $OUT..."

	# replace all known vars
	while IFS='' read -r line || [[ -n "$line" ]]; do
		for varname in ${!CFG_*}; do
			KEY="${varname:4}";
			VAL="${!varname}";
			line="${line//\$\{$KEY\}/$VAL}"
		done;
		echo "$line"
    done < "$TMP" > "$OUT"

	# verify that we catched ALL variables:
	if grep '${' $OUT; then
		echo "ERROR: missed template variables during replacement $IN -> $OUT";
		exit 1;
		#sleep 2
	fi;
done;

