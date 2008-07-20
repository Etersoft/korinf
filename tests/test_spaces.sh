#!/bin/sh
# 2006 (c) Etersoft www.etersoft.ru
# Public domain

. /etc/rpm/etersoft-build-functions

cd `dirname $0`/..

. functions/config.in || fatal "Can't locate config.in"
#. functions/autobuild-functions.sh
. functions/log.sh

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

