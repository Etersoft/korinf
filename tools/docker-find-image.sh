#!/bin/sh

function showhelp()
{
	echo -e "    arg: regexp"
	echo -e "EXAMPLE: docker-find-image.sh *ubuntu*"
}

echo "$1" | grep -w  "help\|-h\|--help"
[ "$#" -eq 0 -o "$?" -eq 0 ]  && showhelp || docker images --filter reference="$1" 

