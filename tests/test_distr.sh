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


check SomeDistro/2010 i586 SomeDistro 2010
check i686/SomeDistro/2010 i686 SomeDistro 2010
check x86_64/SomeDistro/2010 x86_64 SomeDistro 2010

check SomeDistro i586 "" ""
check "SomeDistro 2010" i586 "" ""

check_source()
{
	SOURCES=$(get_rpm_sources "$1")
	[ "$SOURCES" != "$2" ] && echo "Error: wait for '$2', but get '$SOURCES' for $1" || echo "OK for $1"
}

PATHSOURCE=$(readlink -f "/var/ftp/pub/Etersoft/WINE@Etersoft/last/sources")

TESTSYSTEM=Ubuntu/9.04
PGVERSION=last

# FIXME: check correctly only if real target exists
check_source /var/ftp/pub/Etersoft/WINE@Etersoft/last/WINE/$TESTSYSTEM $PATHSOURCE
check_source /var/ftp/pub/Etersoft/WINE@Etersoft/last/WINE/x86_64/$TESTSYSTEM $PATHSOURCE
check_source /var/ftp/pub/Etersoft/WINE@Etersoft/last/x86_64/$TESTSYSTEM $PATHSOURCE
check_source /var/ftp/pub/Etersoft/WINE@Etersoft/last/$TESTSYSTEM $PATHSOURCE
check_source /var/ftp/pub/Etersoft/Postgres@Etersoft/$PGVERSION/Windows /var/ftp/pub/Etersoft/Postgres@Etersoft/$PGVERSION/sources

SOURCEPATH=/var/ftp/pub/Etersoft/Postgres@Etersoft/$PGVERSION/sources
PRVERSION=
if [ -z "$PRVERSION" ] ; then
	# get PROJECT version from SOURCEPATH
	PRVERSION=$(basename $(dirname $SOURCEPATH) )
fi
echo $PRVERSION
