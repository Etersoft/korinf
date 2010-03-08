#!/bin/sh

# Script to publish WINE@Etersoft in LINUX@Etersoft distro

# load common functions, compatible with local and installed script
. `dirname $0`/../share/eterbuild/korinf/common
load_mod alt

PROJECTVERSION=$1
[ -n "$PROJECTVERSION" ] || PROJECTVERSION=last

[ -n "$BUILDNAME" ] || BUILDNAME=wine-etersoft

[ "$(hostname -f)" = "server.office.etersoft.ru" ] || fatal "Please run me only on server in Etersoft office."

SOURCEPATH=$WINEPUB_PATH/$PROJECTVERSION/sources

add_and_remove()
{
	local i=$2
	cd $1 || fatal "Can't cd"
	#ls -l
	local LIST="$i-[0-9]*.*.rpm"
	rm -fv $TP/$i-[0-9]*.rpm
	cp -flv $LIST $TP || cp -fv $LIST $TP || fatal "Can't copy $LIST"
	cd - >/dev/null
}

# FROM TARGET
copy_to()
{
	ARCH=$1
	shift
	local FPU="$WINEPUB_PATH/$PROJECTVERSION/WINE/$ARCH/$1"
	local TP="$2/$ARCH/RPMS.nonfree"

	add_and_remove "$FPU" wine-etersoft
	add_and_remove "$FPU" wine-etersoft-gl
	add_and_remove "$FPU/extra" wine-etersoft-twain
	add_and_remove "$FPU/extra" libwine-etersoft-devel

	add_and_remove "$FPU" haspd
	add_and_remove "$FPU" haspd-modules

	add_and_remove "$WINEETER_PATH/$PROJECTVERSION/WINE-SQL/$1" wine-etersoft-sql
	add_and_remove "$WINEETER_PATH/$PROJECTVERSION/WINE-Network/$1" wine-etersoft-network
	add_and_remove "$WINEETER_PATH/$PROJECTVERSION/WINE-Local/$1" wine-etersoft-local

	FPU="$WINEPUB_PATH/$PROJECTVERSION/CIFS/$1"
	#TP="$2/noarch/RPMS.addon"
	add_and_remove "$FPU" etercifs

	set_binaryrepo $(basename $1)
	ssh git.eter genbases -b $BINARYREPO
}

distro_path=/var/ftp/pub/Etersoft/LINUX@Etersoft
arch=i586

copy_to arch ALTLinux/4.1 $distro_path/4.1/branch
copy_to arch ALTLinux/5.1 $distro_path/5.1/branch
copy_to arch ALTLinux/Sisyphus $distro_path/Sisyphus

