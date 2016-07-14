#!/bin/sh

# load common functions, compatible with local and installed script
. `dirname $0`/../share/eterbuild/korinf/common

NAME="$1"
#PATHTO=/var/ftp/pub/Etersoft/CIFS@Etersoft.cc/3.2
PATHTO="$2"
PSD="$PATHTO/sources"

LATEST=$(ls -1 $PATHTO/sources/$NAME* | last_rpm) || exit
LATEST="$PSD/$LATEST.src.rpm"
[ -s "$LATEST" ] || exit

echo "Check in $PSD ..."
for i in $(ls -1 $PATHTO/sources/$NAME*); do
	[ "$i" = "$LATEST" ] && continue
	echo "Removing $i ..."
	rm -rfv $i
done
