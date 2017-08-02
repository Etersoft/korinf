#!/bin/sh

# Script to publish WINE@Etersoft in LINUX@Etersoft distro

# load common functions, compatible with local and installed script
. `dirname $0`/../share/eterbuild/korinf/common
load_mod alt

PROJECTVERSION=$1
if [ -z "$PROJECTVERSION" ] ; then
	PROJECTVERSION=last
	UNIPVERSION=last
	COMPONENT=unstable
else
	UNIPVERSION=$PROJECTVERSION
	COMPONENT=nonfree
fi

[ "$(hostname -f)" = "server.office.etersoft.ru" ] || fatal "Please run me only on server in Etersoft office."

SOURCEPATH=$WINEPUB_PATH/$PROJECTVERSION/sources

. `dirname $0`/publish-funcs.sh

# FROM TARGET
other_copy_to()
{
	local ARCH=$1
	shift
	NARCH=
	[ "$ARCH" = "i586" ] || NARCH=$ARCH

	local PLATFORM=$1
	shift

	local TP="$2/$ARCH/RPMS.$COMPONENT"

	GENBASE=
	FPU="/var/ftp/pub/Etersoft/RX@Etersoft/$UNIPVERSION/$NARCH/$1"
	add_and_remove "$FPU" nx
	add_and_remove "$FPU" nxclient
	add_and_remove "$FPU" rx-etersoft

	FPU="/var/ftp/pub/Etersoft/Postgre@Etersoft/$UNIPVERSION/$NARCH/$1"
	for i in libpq* postgre-etersoft* postgre-etersoft*-seltaaddon postgre-etersoft*-server; do
		add_and_remove "$FPU" $i
	done

	gen_baserepo $PLATFORM
}

distro_path=/var/ftp/pub/Etersoft/LINUX@Etersoft

for arch in i586 x86_64 ; do
	#other_copy_to "$arch" p5 ALTLinux/p5 $distro_path/p5/branch
	exit
	other_copy_to "$arch" Sisyphus ALTLinux/Sisyphus $distro_path/Sisyphus
	other_copy_to "$arch" p6 ALTLinux/p6 $distro_path/p6/branch
	#other_copy_to "$arch" t6 ALTLinux/p6 $distro_path/t6/branch
	other_copy_to "$arch" p7 ALTLinux/p7 $distro_path/p7/branch
	#other_copy_to "$arch" t7 ALTLinux/p7 $distro_path/t7/branch
done
