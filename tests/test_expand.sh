#!/bin/sh
# 2006 (c) Etersoft www.etersoft.ru
# Public domain

# load common functions, compatible with local and installed script
. `dirname $0`/../share/eterbuild/korinf/common

kormod distro

comp()
{
	local TT=$2
	local ET=$3
	local RS=$1
	#local RS=`eval echo "$TT"`
	[ "$RS" != "$ET" ] && echo "Error: wait for '$ET' in '$TT', but get '$RS'" || echo "OK for $TT with '$RS'"
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

major=8.3
pname=postgresql
pnamever=${pname}-${major}eter

export MAINFILESLIST="${pnamever}[-_][0-9] ${pnamever}-contrib[-_][0-9] ${pnamever}-libs[-_][0-9] ${pnamever}-server[-_][0-9]"
export EXTRAFILESLIST="${pnamever}-devel[-_][0-9] ${pnamever}-docs[-_][0-9] ${pnamever}-plperl[-_][0-9] ${pnamever}-plpython[-_][0-9] ${pnamever}-test[-_][0-9]"

TARGET=deb
prepare_filelist

echo "MAINFILESLIST: $MAINFILESLIST"
echo "EXTRAFILESLIST: $EXTRAFILESLIST"

echo "EXPMAINFILES: $EXPMAINFILES"
echo "EXPEXTRAFILES: $EXPEXTRAFILES"

# expand file masks by rpm
echo "EXPRPMMAINFILES: $EXPRPMMAINFILES"
echo "EXPRPMEXTRAFILES: $EXPRPMEXTRAFILES"
