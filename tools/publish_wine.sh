#!/bin/sh

# Script to publish WINE@Etersoft in LINUX@Etersoft distro

# load common functions, compatible with local and installed script
. `dirname $0`/../share/eterbuild/korinf/common

PROJECTVERSION=$1
[ -n "$PROJECTVERSION" ] || PROJECTVERSION=last

[ -n "$BUILDNAME" ] || BUILDNAME=wine-etersoft

SOURCEPATH=$WINEPUB_PATH/$PROJECTVERSION/sources

if [ -z "$VERSION" ] ; then
	BUILDSRPM="$SOURCEPATH/$(ls -1 $SOURCEPATH/$BUILDNAME-[0-9]*.src.rpm | last_rpm).src.rpm"
	# почему-то не последний пакет
	echo $BUILDSRPM
	VERSION=`rpm -qp --queryformat "%{VERSION}" $BUILDSRPM`
	#RELEASE=`rpm -qp --queryformat "%{RELEASE}" $BUILDSRPM`
fi

# FROM TARGET
copy_to()
{
	local FPU="$WINEPUB_PATH/$PROJECTVERSION/WINE/$1"
	local TP="$2/i586/RPMS.nonfree"

	cd "$FPU" || fatal "Can't cd"
	LIST=
	for i in wine-etersoft ; do
		LIST="$LIST $i-$VERSION-*.*.rpm"
		rm -fv $TP/$i-[0-9]*.rpm
	done

	for i in wine-etersoft-gl ; do
		LIST="$LIST extra/$i-$VERSION-*.*.rpm"
		rm -fv $TP/$i-[0-9]*.rpm
	done

	cp -fv $LIST $TP

	local FPV="$WINEETER_PATH/$PROJECTVERSION/WINE-SQL/$1"
	cd "$FPV" || fatal "Can't cd"
	LIST=
	for i in wine-etersoft-sql ; do
		LIST="$LIST $i-$VERSION-*.*.rpm"
		rm -fv $TP/$i-[0-9]*.rpm
	done
	cp -fv $LIST $TP

	local FPV="$WINEETER_PATH/$PROJECTVERSION/WINE-Network/$1"
	cd "$FPV" || fatal "Can't cd"
	LIST=
	for i in wine-etersoft-network ; do
		LIST="$LIST $i-$VERSION-*.*.rpm"
		rm -fv $TP/$i-[0-9]*.rpm
	done
	cp -fv $LIST $TP

	local FPV="$WINEETER_PATH/$PROJECTVERSION/WINE-Local/$1"
	cd "$FPV" || fatal "Can't cd"
	LIST=
	for i in wine-etersoft-local ; do
		LIST="$LIST $i-$VERSION-*.*.rpm"
		rm -fv $TP/$i-[0-9]*.rpm
	done
	cp -fv $LIST $TP

	genbasedir -v --topdir=$2 i586 nonfree
}

copy_to ALTLinux/4.1 /var/ftp/pub/Etersoft/LINUX@Etersoft/4.1/branch
copy_to ALTLinux/5.0 /var/ftp/pub/Etersoft/LINUX@Etersoft/5.0/branch
copy_to ALTLinux/Sisyphus /var/ftp/pub/Etersoft/LINUX@Etersoft/Sisyphus

