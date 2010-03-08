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
	REAL=`get_target_list "$TEST1"`
	echo "Source line: '$TEST1' with result '$REAL' (wait for '$REPL1') "
	#REPL=`echo $TEST1 | sed -r -e $NRL`
	#REPL=`echo $TEST1 | perl -pi "$NRL"`
	[ "$REPL1" != "$REAL" ] && failure || success
	echo
	echo
}

TARGETPATH=$(realpath .)
LISTS=$KORINFETC/lists

check "$TARGETPATH/distro.list" ""
check "$LISTS/ALL" "ALL"
check "$TARGETPATH/distro.list" "gen"
check "$TARGETPATH/distro.list" "alt"

TARGETPATH=/var/empty
check "$LISTS/ALL" ""
check "$LISTS/ALL" "ALL"
check "$LISTS/ALL" "ALL"
check "$LISTS/gen" "gen"
check "$LISTS/alt" "alt"
