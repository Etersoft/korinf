#!/bin/sh

# load common functions, compatible with local and installed script
. `dirname $0`/../share/eterbuild/korinf/common

VERSION=$1
RELEASE=$2
NAME=$WINEPUB_PATH/$VERSION

cd $WINEPUB_PATH/$VERSION-eter$RELEASE/WINE/ALTLinux/Sisyphus || fatal "Can't cd"


LIST=
for i in wine libwine libwine-devel libwine-twain libwine-gl ; do
	rpm -q $i &>/dev/null && LIST="$LIST $i-$VERSION-*$RELEASE.*.rpm"
done

for i in libwine-devel libwine-twain libwine-gl ; do
	rpm -q $i &>/dev/null && LIST="$LIST extra/$i-$VERSION-*$RELEASE.*.rpm"
done

echo $LIST
rpmU $LIST $3 --force

