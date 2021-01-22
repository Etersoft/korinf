#!/bin/bash

for i in $(ls ../../../sales/*.task*) 
		do
		    realpath $i |egrep --color "([0-9A-Z]{4}-[0-9A-Z]{4})" 
		    cat $i | egrep "DIST|FAILED|DOWNLOADDIR|PRODUCT" |sort -u | egrep --color "(DIST|FAILED|DOWNLOADDIR|PRODUCT)"
		    echo "  "
		done
