#!/bin/sh
# Выводит сообщения о ненайденных вайновским configure библиотеках
#
# ./script 1.2.3 wine /var/ftp/pub/Etersoft/Wine-public

# load common functions, compatible with local and installed script
. `dirname $0`/../share/eterbuild/korinf/common

[ "$1" = "-v" ] && { VERBOSE=1 ; shift ; }
IPATH="WINE"
[ -n "$1" ] && VERSION="$1" || VERSION=last
[ -n "$2" ] && PACKAGENAME="$2" || PACKAGENAME=wine-etersoft
[ -n "$3" ] && { WINEPUB_PATH="$3" ; IPATH="" ; }
[ -n "$4" ] && SKIPPED="$4" || SKIPPED="libcapi|OpenCL"
NAME=$WINEPUB_PATH/$VERSION

[ -n "$VERBOSE" ] && echo "Check in $NAME for $PACKAGENAME package..."
for n in $(get_distro_list $NAME) ; do
	FILE=$NAME/$IPATH/$n/log/$PACKAGENAME.log.bz2
	res=$(bzcat $FILE | grep "configure:" | grep development | grep found | sed -e "s|^configure:|          |g" | grep -E -v "($SKIPPED)")
	if [ -n "$VERBOSE" ] || [ -n "$res" ] ; then
		echo
		echo "$NAME/$n: (`stat -c "%y" $FILE`)"
		echo "$res"
	fi
done
