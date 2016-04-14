#!/bin/bash

# (c) Etersoft 2009-2012
# Script to install WINE@Etersoft to ALT Linux Sisyphus or Ubuntu based system

# Args
# 1. version (2.0 or last or testing)
# 2. product (empty for WINE@Etersoft, vanilla or public for other)

# load common functions, compatible with local and installed script
. `dirname $0`/../share/eterbuild/korinf/common

if [ "$1" = "-f" ] ; then
	FORCE="--force"
	shift
fi

if [ "$1" = "-i" ] ; then
	INITIAL="1"
	shift
fi

PROJECTVERSION=$1
[ -n "$PROJECTVERSION" ] || PROJECTVERSION=last

LIBBUILDNAME=
EXTRADIR=extra/
BASEBUILDNAME=$2
if [ -n "$BASEBUILDNAME" ] ; then
    BUILDNAME=wine-$BASEBUILDNAME
    [ "$BASEBUILDNAME" = "public" ] && BUILDNAME=wine
    LIBBUILDNAME=lib$BUILDNAME
    EXTRADIR=
fi

[ -n "$BUILDNAME" ] || BUILDNAME=wine-etersoft

PRIVPART='SQL'
[ "$PROJECTVERSION" = "cad" ] && PRIVPART='CAD'

#SYSTEM=ALTLinux/Sisyphus
# p6 - needs some release rewrite (alt14 -> alt13.M60P.14)
#SYSTEM=ALTLinux/p7
SYSTEM=$(distr_info)


# TODO: move to etersoft-build-utils spec
get_txtpartrelease()
{
	echo "$1" | sed -e "s|\([a-zA-Z]*\)\([0-9\.]\).*|\1|" || get_default_txtrelease
}


get_version_release()
{
	SOURCEPATH=$TARGETPATH/../../../../sources
	[ -d "$SOURCEPATH" ] || SOURCEPATH=$TARGETPATH/../../../sources
	[ -d "$SOURCEPATH" ] || SOURCEPATH=$TARGETPATH/../../sources

if [ -z "$VERSION" ] ; then
	BUILDSRPM="$SOURCEPATH/$(ls -1 $SOURCEPATH/$BUILDNAME-[0-9]*.src.rpm | last_rpm).src.rpm"
	# FIXME: почему-то не последний пакет
	echo $BUILDSRPM
	VERSION=`rpm -qp --queryformat "%{VERSION}" $BUILDSRPM`
	RELEASE=`rpm -qp --queryformat "%{RELEASE}" $BUILDSRPM`
	if [ "$DISTRIB_ID" = "Ubuntu" ] ; then
		RELEASE=eter`echo "$RELEASE" | sed -e "s|\([a-zA-Z]*\)\([0-9\.]\)[^0-9\.]*|\2|" `ubuntu
	fi

	if [ "$SYSTEM" != "ALTLinux/Sisyphus" ] ; then
		# TODO: fix RELEASE
		load_mod spec
		# TODO: $(get_altdistr_mod $BINARYREPO)
		MDISTR=M70P
		local BASERELEASE=$(get_numpartrelease $RELEASE)
		RELEASE=$(get_txtpartrelease $RELEASE)$(decrement_release $BASERELEASE).$MDISTR.$BASERELEASE

	fi
fi
}

pkg_is_installed()
{
	test -n "$INITIAL" && return
	epm installed "$1" &>/dev/null
}

install_pkg()
{
	echo $LIST
	test -n "$LIST" || return
	NODEPS=--nodeps
	[ -n "$INITIAL" ] && NODEPS=
	epm install --auto $NODEPS $FORCE $LIST
}

#############
# FIXME: use distr_info
if [ -r "/etc/lsb-release" ] && [ ! -r "/etc/altlinux-release" ] ; then
	. /etc/lsb-release
	SYSTEM=$DISTRIB_ID/$DISTRIB_RELEASE
	if [ $DEFAULTARCH = "x86_64" ] ; then
		SYSTEM="x86_64/$SYSTEM"
	fi
	EXT=deb

else
	EXT=rpm
fi

if [ -n "$BASEBUILDNAME" ] ; then
	TARGETPATH=/var/ftp/pub/Etersoft/Wine-$BASEBUILDNAME/$PROJECTVERSION/$SYSTEM
else
	TARGETPATH=$WINEPUB_PATH/$PROJECTVERSION/WINE/$SYSTEM
fi
get_version_release

if cd $TARGETPATH ; then
	pwd

	LIST=
	for i in $LIBBUILDNAME $BUILDNAME $BUILDNAME-gl ; do
		pkg_is_installed $i && LIST="$LIST $i[-_]$VERSION-*$RELEASE[._]*.$EXT"
	done

	# FIXME: not for wine / wine-vanilla
	for i in lib$BUILDNAME-devel $BUILDNAME-twain ; do
		pkg_is_installed $i && LIST="$LIST $EXTRADIR$i[-_]$VERSION-*$RELEASE[._]*.$EXT"
	done

	install_pkg
	RESULT=$(echo $?)
	[ $RESULT -eq 100 ] && echo "There are no proper packages in Sisyphus directory or wrong version" >&2
fi

#############
# private public
VERSION=
BUILDNAME=$BUILDNAME-$(echo $PRIVPART | tr [A-Z] [a-z])
TARGETPATH=$WINEETER_PATH/$PROJECTVERSION/WINE-$PRIVPART/$SYSTEM
get_version_release

cd $TARGETPATH || fatal "Can't cd"
pwd

LIST=
for i in $BUILDNAME ; do
	pkg_is_installed $i && LIST="$LIST $i[-_]$VERSION-*$RELEASE[._]*.$EXT"
done

install_pkg
