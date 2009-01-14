#!/bin/sh

# load common functions, compatible with local and installed script
. `dirname $0`/../share/eterbuild/korinf/common

VERSION=$1
RELEASE=$2
[ -n "$3" ] && PROJECTVERSION=$3 || PROJECTVERSION=$VERSION-eter$RELEASE

cd $WINEPUB_PATH/$PROJECTVERSION/WINE/ALTLinux/Sisyphus || fatal "Can't cd"
pwd

LIST=
for i in wine libwine libwine-devel libwine-twain libwine-gl ; do
	rpm -q $i &>/dev/null && LIST="$LIST $i-$VERSION-*$RELEASE.*.rpm"
done

for i in libwine-devel libwine-twain libwine-gl ; do
	rpm -q $i &>/dev/null && LIST="$LIST extra/$i-$VERSION-*$RELEASE.*.rpm"
done

echo $LIST
rpmU $LIST --force

