#!/bin/sh
#
# Remove build.failed files
#

# load common functions, compatible with local and installed script
. `dirname $0`/../share/eterbuild/korinf/common


FTPPATH=/var/ftp/pub/Etersoft
PRODLIST="CIFS@Etersoft/* HASP/* Postgres@Etersoft/* RX@Etersoft/* WINE@Etersoft/*/WINE WINE@Etersoft/*/fonts Wine-public/* Wine-vanilla/*"

if [ "$1" = "-h" ] ; then
	echo "Run without params for remove from all dirs or with product name as arg"
	exit
fi

PRODNAME=$1

for p in $PRODLIST ; do
	# skip all exclude PRODNAME if PRODNAME is filled
	if [ -n "$PRODNAME" ] ; then
		echo "$p" | grep -q $PRODNAME || continue
	fi

	VERLIST=$(echo $FTPPATH/$p)
	for v in $VERLIST ; do
		echo "Check in $v"
		#for n in $(get_distro_list $v) ; do
		for n in $v/x86_64/*/* $v/*/* ; do
			[ -d "$n" ] || continue
			rm -vf $n/log/*.build.failed
			rm -vf $n/log/*.autobuild.failed
		done
	done
done
