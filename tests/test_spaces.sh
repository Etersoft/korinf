#!/bin/sh
# 2006 (c) Etersoft www.etersoft.ru
# Public domain

# load common functions, compatible with local and installed script
. `dirname $0`/../share/eterbuild/korinf/common

. $KORINFDIR/korinf/config.in || fatal "Can't locate config.in"

load_kormod log

check()
{
	local REPL
	echo
	echo -n "Source line: '$TEST1' with result '$REAL' "
	#REPL=`echo $TEST1 | sed -r -e $NRL`
	#REPL=`echo $TEST1 | perl -pi "$NRL"`
	[ "$REPL1" != "$REAL" ] && failure || success
	echo
}

TEST1="ALT"
REPL1="   "
REAL=`print_spaces_instead_string "$TEST1"`
check

TEST1="ALTLinux/4.0"
REPL1="            "
REAL=`print_spaces_instead_string "$TEST1"`
check


TEST1="ALT Linux 4.0"
REPL1="             "
REAL=`print_spaces_instead_string "$TEST1"`
check

