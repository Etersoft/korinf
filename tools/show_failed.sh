#!/bin/bash

for i in $(ls ../../../sales/*.task*) 
		do
		    realpath $i |grep -E --color "([0-9A-Z]{4}-[0-9A-Z]{4})" 
		    cat $i | grep -E "DIST|FAILED|DOWNLOADDIR|PRODUCT" |sort -u | grep -E --color "(DIST|FAILED|DOWNLOADDIR|PRODUCT)"
		    echo "  "
		done
