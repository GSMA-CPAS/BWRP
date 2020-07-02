#!/bin/bash
CONFIG=$1
OUTPUT=$2

source $CONFIG

# copy templates to output
# and replace all known variables
TMP=$(mktemp)
for file in $(find template/ -type f -printf "%P\n"); do
	IN=template/$file
	ls -la  $IN
	OUT=$OUTPUT/$file
	cp -r $IN $TMP
	
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
		#exit 1;
		#sleep 2
	fi;
done;

