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
	REAL=`get_linked_system "$TEST1"`
	echo "Source line: '$TEST1' with result '$REAL' (wait for '$REPL1') "
	#REPL=`echo $TEST1 | sed -r -e $NRL`
	#REPL=`echo $TEST1 | perl -pi "$NRL"`
	[ "$REPL1" != "$REAL" ] && failure || success
	echo
	echo
}

check "ALTLinux/4.1" "LINUX@Etersoft/4.1"
check "" "ALTLinux/5.0"
