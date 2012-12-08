#!/bin/sh

# Script to publish WINE@Etersoft in LINUX@Etersoft distro

# load common functions, compatible with local and installed script
. `dirname $0`/../share/eterbuild/korinf/common
load_mod alt

PROJECTVERSION=$1
if [ -z "$PROJECTVERSION" ] ; then
	PROJECTVERSION=last
	UNIPVERSION=2.0-testing
	COMPONENT=unstable
else
	UNIPVERSION=stable
	COMPONENT=nonfree
fi

[ -n "$BUILDNAME" ] || BUILDNAME=wine-etersoft

[ "$(hostname -f)" = "server.office.etersoft.ru" ] || fatal "Please run me only on server in Etersoft office."

SOURCEPATH=$WINEPUB_PATH/$PROJECTVERSION/sources

add_and_remove()
{
	local i=$2
	[ -n "$i" ] || return
	cd $1 || { warning "Can't cd" ; return ; }
	#ls -l
	local LIST="$i-[0-9]*.*.rpm"
	for file in $LIST ; do
		[ -r "$file" ] || { echo "Skip $file (missed now)" ; continue ; }
		cmp "$file" $TP/$(basename $file) && { echo "Skip $file (not changed)" ; continue ; }
		cp -flv $file $TP 2>/dev/null || cp -fv $file $TP || fatal "Can't copy $file"
	done
	#rm -fv $TP/$i-[0-9]*.rpm
	#echo "## $(pwd) ## $LIST"
	cd - >/dev/null
}

# FROM TARGET
wine_copy_to()
{
	ARCH=$1
	shift
	NARCH=
	[ "$ARCH" = "i586" ] || NARCH=$ARCH
	local FPU="$WINEPUB_PATH/$PROJECTVERSION/WINE/$NARCH/$1"
	local HASPFPU="$WINEPUB_PATH/$PROJECTVERSION/HASP/$NARCH/$1"
	local TP="$2/$ARCH/RPMS.$COMPONENT"

	add_and_remove "$FPU" wine-etersoft
	add_and_remove "$FPU/extra" wine-etersoft-gl
	add_and_remove "$FPU/extra" wine-etersoft-twain
	add_and_remove "$FPU/extra" libwine-etersoft-devel

	add_and_remove "$HASPFPU" haspd
	add_and_remove "$HASPFPU" haspd-modules

	add_and_remove "$WINEETER_PATH/$PROJECTVERSION/WINE-SQL/$1" wine-etersoft-sql
	add_and_remove "$WINEETER_PATH/$PROJECTVERSION/WINE-Network/$1" wine-etersoft-network
	add_and_remove "$WINEETER_PATH/$PROJECTVERSION/WINE-Local/$1" wine-etersoft-local

	FPU="$WINEPUB_PATH/$PROJECTVERSION/CIFS/$1"
	#TP="$2/noarch/RPMS.addon"
	add_and_remove "$FPU" etercifs

}

distro_path=/var/ftp/pub/Etersoft/LINUX@Etersoft

arch=i586
#copy_to "$arch" ALTLinux/4.1 $distro_path/4.1/branch
wine_copy_to "$arch" ALTLinux/p5 $distro_path/p5/branch
wine_copy_to "$arch" ALTLinux/Sisyphus $distro_path/Sisyphus
wine_copy_to "$arch" ALTLinux/p6 $distro_path/p6/branch
wine_copy_to "$arch" ALTLinux/p6 $distro_path/t6/branch

arch=x86_64
##copy_to "$arch" ALTLinux/4.1 $distro_path/4.1/branch
#other_copy_to "$arch" ALTLinux/p5 $distro_path/p5/branch
#other_copy_to "$arch" ALTLinux/Sisyphus $distro_path/Sisyphus
#other_copy_to "$arch" ALTLinux/p6 $distro_path/p6/branch
#other_copy_to "$arch" ALTLinux/p6 $distro_path/t6/branch
