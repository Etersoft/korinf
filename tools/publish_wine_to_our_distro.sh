#!/bin/sh

# Script to publish WINE@Etersoft in LINUX@Etersoft distro

# load common functions, compatible with local and installed script
. `dirname $0`/../share/eterbuild/korinf/common
load_mod alt

PROJECTVERSION=$1
[ -z "$PROJECTVERSION" ] && fatal "Run with version (2.0, 2.0-testing and so on)"

if echo "$PROJECTVERSION" | grep -q testing ; then
	COMPONENT=unstable
else
	COMPONENT=nonfree
fi

[ -n "$BUILDNAME" ] || BUILDNAME=wine-etersoft

[ "$(hostname -f)" = "server.office.etersoft.ru" ] || fatal "Please run me only on server in Etersoft office."

SOURCEPATH=$WINEPUB_PATH/$PROJECTVERSION/sources

. `dirname $0`/publish-funcs.sh

# FROM TARGET
wine_copy_to()
{
	ARCH=$1
	shift
	NARCH=
	[ "$ARCH" = "i586" ] || NARCH=$ARCH

	PLATFORM=$1
	shift
	
	local FPU="$WINEPUB_PATH/$PROJECTVERSION/WINE/$NARCH/$1"
	local HASPFPU="$WINEPUB_PATH/$PROJECTVERSION/HASP/$NARCH/$1"
	local TP="$2/$ARCH/RPMS.$COMPONENT"

	GENBASE=
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

	gen_baserepo $PLATFORM
}

distro_path=/var/ftp/pub/Etersoft/LINUX@Etersoft

for arch in i586 ; do
	#wine_copy_to "$arch" p5 ALTLinux/p5 $distro_path/p5/branch
	wine_copy_to "$arch" Sisyphus ALTLinux/Sisyphus $distro_path/Sisyphus
	#wine_copy_to "$arch" p6 ALTLinux/p6 $distro_path/p6/branch
	#wine_copy_to "$arch" t6 ALTLinux/p6 $distro_path/t6/branch
	wine_copy_to "$arch" p7 ALTLinux/p7 $distro_path/p7/branch
	wine_copy_to "$arch" p8 ALTLinux/p8 $distro_path/p8/branch
	#wine_copy_to "$arch" t7 ALTLinux/p7 $distro_path/t7/branch
done
