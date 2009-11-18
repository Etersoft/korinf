#!/bin/sh
# 2006 (c) Etersoft www.etersoft.ru
# Public domain

# load common functions, compatible with local and installed script
. `dirname $0`/../share/eterbuild/korinf/common

check()
{
	local REPL
	TEST1="$1"
	REPL1="$2"
	REAL=`get_distro_list "$TEST1"`
	echo -n "Source line: '$TEST1' with result '$REAL' (wait for '$REPL1') "
	#REPL=`echo $TEST1 | sed -r -e $NRL`
	#REPL=`echo $TEST1 | perl -pi "$NRL"`
	[ "$REPL1" != "$REAL" ] && failure || success
	echo
	echo
}

check SomeDistro/2010 "SomeDistro/2010"
check "SomeDistro/2010 SomeLinux/2020" "SomeDistro/2010 SomeLinux/2020"

cat <<EOF >test1
#
SomeDistro/2010
SomeDistro/2011
SomeLinux/2020
EOF
check test1 "SomeDistro/2010
SomeDistro/2011
SomeLinux/2020"

cat <<EOF >test2
#
. test1
EndLinux/2038
EOF
check test2 "EndLinux/2038
SomeDistro/2010
SomeDistro/2011
SomeLinux/2020"

SKIPBUILDLIST="EndLinux"
echo "with skip $SKIPBUILDLIST"
check test2 "SomeDistro/2010
SomeDistro/2011
SomeLinux/2020"

SKIPBUILDLIST="SomeDistro/2010"
echo "with skip $SKIPBUILDLIST"
check test2 "EndLinux/2038
SomeDistro/2011
SomeLinux/2020"

SKIPBUILDLIST="SomeDistro"
echo "with skip $SKIPBUILDLIST"
check test2 "EndLinux/2038
SomeLinux/2020"

rm -f test1 test2
