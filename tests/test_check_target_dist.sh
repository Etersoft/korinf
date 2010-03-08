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
	check_target_dist "$TEST1"
	REAL=$?
	echo "Source line: '$TEST1' with result '$REAL' (wait for '$REPL1') "
	#REPL=`echo $TEST1 | sed -r -e $NRL`
	#REPL=`echo $TEST1 | perl -pi "$NRL"`
	[ "$REPL1" != "$REAL" ] && failure || success
	echo
	echo
}

TARGETPATH=/var/ftp/pub/Etersoft/WINE@Etersoft/last
LISTS=$KORINFETC/lists

check "0" "ALTLinux/4.1"
check "0" "LINUX@Etersoft/4.1"
check "1" "LINUX@Etersoft/9.9"

TARGETPATH=/var/empty
