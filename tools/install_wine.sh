#!/bin/sh

# load common functions, compatible with local and installed script
. `dirname $0`/../share/eterbuild/korinf/common

PROJECTVERSION=$1
[ -n "$PROJECTVERSION" ] || PROJECTVERSION=last

BUILDNAME=wine
TARGETPATH=$WINEPUB_PATH/$PROJECTVERSION/WINE/ALTLinux/Sisyphus
SOURCEPATH=$WINEPUB_PATH/$PROJECTVERSION/sources

if [ -z "$VERSION" ] ; then
	BUILDSRPM="$SOURCEPATH/$(ls -1 $SOURCEPATH/$BUILDNAME-[0-9]*.src.rpm | last_rpm).src.rpm"
	# почему-то не последний пакет
	echo $BUILDSRPM
	VERSION=`rpm -qp --queryformat "%{VERSION}" $BUILDSRPM`
	RELEASE=`rpm -qp --queryformat "%{RELEASE}" $BUILDSRPM`
fi


cd $TARGETPATH || fatal "Can't cd"
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

