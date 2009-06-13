#!/bin/sh
# 2006 (c) Etersoft www.etersoft.ru
# Public domain

# load common functions, compatible with local and installed script
. `dirname $0`/../share/eterbuild/korinf/common


comp()
{
	local TT=$2
	local ET=$3
	local RS=$1
	#local RS=`eval echo "$TT"`
	[ "$RS" != "$ET" ] && echo "Error: wait for '$ET' in '$TT', but get '$RS'" || echo "OK for $TT"
}

check()
{
	local REPL
	TEST1="$1"
	shift
	parse_dist_name "$TEST1"
	echo
	echo "Source line: '$TEST1' (wait for '$@') "
	comp "$dist_arch" dist_arch $1
	comp "$dist_name" dist_name $2
	comp "$dist_ver" dist_ver $3
	echo
}


check SomeDistro/2010 i586 SomeDistro 2010
check i686/SomeDistro/2010 i686 SomeDistro 2010
check x86_64/SomeDistro/2010 x86_64 SomeDistro 2010

check SomeDistro i586 "" ""
check "SomeDistro 2010" i586 "" ""
