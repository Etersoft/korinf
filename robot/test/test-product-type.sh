#!/bin/sh

cd ..
# load common functions, compatible with local and installed script
. `dirname $0`/../share/eterbuild/korinf/common

AROBOTDIR=$(pwd)

. $AROBOTDIR/funcs/common
. $AROBOTDIR/funcs/task
. $AROBOTDIR/funcs/etersoft

check_o()
{
	echo -n "Source line: '$2' with result '$3' "
	[ "$2" != "$3" ] && failure || success
	echo
}

check()
{
	check_o "$1" "$2" "$(get_product_type "$1")"
}

check "Network Lite" "NetworkLite"
check "SQL" "SQL"
check "WINE@Etersoft CAD" "CAD"
