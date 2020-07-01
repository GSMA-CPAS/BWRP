#!/bin/bash
source setup.cfg

# copy config variables to ENV
for varname in ${!CFG_*}; do
    KEY="${varname:4}";
    VAL="${!varname}";
    export $KEY=$VAL
done;