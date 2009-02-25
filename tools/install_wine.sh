#!/bin/sh

# Script to install WINE@Etersoft to Sisyphus based system

# load common functions, compatible with local and installed script
. `dirname $0`/../share/eterbuild/korinf/common

PROJECTVERSION=$1
[ -n "$PROJECTVERSION" ] || PROJECTVERSION=last

[ -n "$BUILDNAME" ] || BUILDNAME=wine-etersoft

TARGETPATH=$WINEPUB_PATH/$PROJECTVERSION/WINE/ALTLinux/Sisyphus
SOURCEPATH=$WINEPUB_PATH/$PROJECTVERSION/sources

if [ -z "$VERSION" ] ; then
	BUILDSRPM="$SOURCEPATH/$(ls -1 $SOURCEPATH/$BUILDNAME-[0-9]*.src.rpm | last_rpm).src.rpm"
	# ������-�� �� ��������� �����
	echo $BUILDSRPM
	VERSION=`rpm -qp --queryformat "%{VERSION}" $BUILDSRPM`
	RELEASE=`rpm -qp --queryformat "%{RELEASE}" $BUILDSRPM`
fi


cd $TARGETPATH || fatal "Can't cd"
pwd

LIST=
for i in $BUILDNAME lib$BUILDNAME lib$BUILDNAME-devel lib$BUILDNAME-twain lib$BUILDNAME-gl ; do
	rpm -q $i &>/dev/null && LIST="$LIST $i-$VERSION-*$RELEASE.*.rpm"
done

for i in lib$BUILDNAME-devel lib$BUILDNAME-twain lib$BUILDNAME-gl ; do
	rpm -q $i &>/dev/null && LIST="$LIST extra/$i-$VERSION-*$RELEASE.*.rpm"
done

echo $LIST
rpmU $LIST --force

