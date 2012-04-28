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

add_and_remove()
{
	local i=$2
	[ -n "$i" ] || return
	cd $1 || { warning "Can't cd" ; return ; }
	#ls -l
	local LIST="$i-[0-9]*.*.rpm"
	for i in $LIST ; do
	    [ -r "$i" ] || { echo "Skip $LIST (missed now)" ; return ; }
	done
	rm -fv $TP/$i-[0-9]*.rpm
	#echo "## $(pwd) ## $LIST"
	cp -flv $LIST $TP 2>/dev/null || cp -fv $LIST $TP || fatal "Can't copy $LIST"
	cd - >/dev/null
}

# FROM TARGET
other_copy_to()
{
	ARCH=$1
	shift
	NARCH=
	[ "$ARCH" = "i586" ] || NARCH=$ARCH
	local TP="$2/$ARCH/RPMS.$COMPONENT"

	FPU="/var/ftp/pub/Etersoft/RX@Etersoft/$UNIPVERSION/$NARCH/$1"
	add_and_remove "$FPU" nx
	add_and_remove "$FPU" nxclient
	add_and_remove "$FPU" rx-etersoft

	FPU="/var/ftp/pub/Etersoft/Postgre@Etersoft/$UNIPVERSION/$NARCH/$1"
	for i in libpq5.2-9.0eter libpq5.2-9.0eter postgre-etersoft9.0 postgre-etersoft9.0 postgre-etersoft9.0-seltaaddon postgre-etersoft9.0-server; do
		add_and_remove "$FPU" $i
	done

	set_binaryrepo $(basename $1)
	ssh git.eter genbases -b $BINARYREPO
}

distro_path=/var/ftp/pub/Etersoft/LINUX@Etersoft

arch=i586
#copy_to "$arch" ALTLinux/4.1 $distro_path/4.1/branch
other_copy_to "$arch" ALTLinux/p5 $distro_path/p5/branch
other_copy_to "$arch" ALTLinux/Sisyphus $distro_path/Sisyphus
other_copy_to "$arch" ALTLinux/p6 $distro_path/p6/branch
other_copy_to "$arch" ALTLinux/p6 $distro_path/t6/branch

arch=x86_64
#copy_to "$arch" ALTLinux/4.1 $distro_path/4.1/branch
other_copy_to "$arch" ALTLinux/p5 $distro_path/p5/branch
other_copy_to "$arch" ALTLinux/Sisyphus $distro_path/Sisyphus
other_copy_to "$arch" ALTLinux/p6 $distro_path/p6/branch
other_copy_to "$arch" ALTLinux/p6 $distro_path/t6/branch
