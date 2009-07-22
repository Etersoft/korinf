#!/bin/sh

# Script to install WINE@Etersoft to Sisyphus based system

# load common functions, compatible with local and installed script
. `dirname $0`/../share/eterbuild/korinf/common

if [ "$1" = "-f" ] ; then
	FORCE="--force"
fi

PROJECTVERSION=$1
[ -n "$PROJECTVERSION" ] || PROJECTVERSION=last

[ -n "$BUILDNAME" ] || BUILDNAME=wine-etersoft

get_version_release()
{
SOURCEPATH=$TARGETPATH/../../../sources

if [ -z "$VERSION" ] ; then
	BUILDSRPM="$SOURCEPATH/$(ls -1 $SOURCEPATH/$BUILDNAME-[0-9]*.src.rpm | last_rpm).src.rpm"
	# почему-то не последний пакет
	echo $BUILDSRPM
	VERSION=`rpm -qp --queryformat "%{VERSION}" $BUILDSRPM`
	RELEASE=`rpm -qp --queryformat "%{RELEASE}" $BUILDSRPM`
fi
}

#############
TARGETPATH=$WINEPUB_PATH/$PROJECTVERSION/WINE/ALTLinux/Sisyphus
get_version_release

cd $TARGETPATH || fatal "Can't cd"
pwd

LIST=
for i in $BUILDNAME ; do
	rpm -q $i &>/dev/null && LIST="$LIST $i-$VERSION-*$RELEASE.*.rpm"
done

for i in lib$BUILDNAME-devel $BUILDNAME-twain $BUILDNAME-gl ; do
	rpm -q $i &>/dev/null && LIST="$LIST extra/$i-$VERSION-*$RELEASE.*.rpm"
done

echo $LIST
rpmU $LIST $FORCE


#############
VERSION=
BUILDNAME=$BUILDNAME-sql
TARGETPATH=$WINEETER_PATH/$PROJECTVERSION/WINE-SQL/ALTLinux/Sisyphus
get_version_release

cd $TARGETPATH || fatal "Can't cd"
pwd

LIST=
for i in $BUILDNAME ; do
	rpm -q $i &>/dev/null && LIST="$LIST $i-$VERSION-*$RELEASE.*.rpm"
done

echo $LIST
rpmU $LIST $FORCE

