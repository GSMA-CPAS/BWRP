#!/bin/bash
source setup.cfg
source setup.sh


# copy templates to output
# and replace all known variables
TMP=$(mktemp)
for file in $(find template/ -type f -printf "%P\n"); do
	IN=template/$file
	ls -la  $IN
	OUT=$CFG_CONFIG_PATH/$file
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
	fi;
done;

