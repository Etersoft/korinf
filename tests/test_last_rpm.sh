#!/bin/sh
# 2006 (c) Etersoft www.etersoft.ru
# Public domain

# load common functions, compatible with local and installed script
. `dirname $0`/../share/eterbuild/korinf/common

check()
{
	local REPL
	TEST1="$2"
	REPL1="$1"
	REAL=$(echo "$TEST1" | last_rpm)
	echo "Source line: '$TEST1' with result '$REAL' (wait for '$REPL1') "
	#REPL=`echo $TEST1 | sed -r -e $NRL`
	#REPL=`echo $TEST1 | perl -pi "$NRL"`
	[ "$REPL1" != "$REAL" ] && failure || success
	echo
	echo
}

check "wine-etersoft-1.0.12-alt3" "$(ls -1 /var/ftp/pub/Etersoft/WINE@Etersoft/1.0.12-eter3/sources/wine-etersoft*)"
