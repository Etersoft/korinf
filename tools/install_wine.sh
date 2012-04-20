#!/bin/bash

# Script to install WINE@Etersoft to Sisyphus based system

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

[ -n "$BUILDNAME" ] || BUILDNAME=wine-etersoft

PRIVPART='SQL'
[ "$PROJECTVERSION" = "cad" ] && PRIVPART='CAD'

SYSTEM=ALTLinux/Sisyphus
# p6 - needs some release rewrite (alt14 -> alt13.M60P.14)
#SYSTEM=ALTLinux/p6


get_version_release()
{
	SOURCEPATH=$TARGETPATH/../../../../sources
	[ -d "$SOURCEPATH" ] || SOURCEPATH=$TARGETPATH/../../../sources

if [ -z "$VERSION" ] ; then
	BUILDSRPM="$SOURCEPATH/$(ls -1 $SOURCEPATH/$BUILDNAME-[0-9]*.src.rpm | last_rpm).src.rpm"
	# FIXME: почему-то не последний пакет
	echo $BUILDSRPM
	VERSION=`rpm -qp --queryformat "%{VERSION}" $BUILDSRPM`
	RELEASE=`rpm -qp --queryformat "%{RELEASE}" $BUILDSRPM`
	if [ "$DISTRIB_ID" = "Ubuntu" ] ; then
		RELEASE=eter`echo "$RELEASE" | sed -e "s|\([a-zA-Z]*\)\([0-9\.]\)[^0-9\.]*|\2|" `ubuntu
	fi
fi
}

pkg_is_installed()
{
	test -n "$INITIAL" && return
	if [ "$DISTRIB_ID" = "Ubuntu" ] ; then
		dpkg -s "$1" &>/dev/null
	else
		rpm -q "$1" &>/dev/null
	fi
}

install_pkg()
{
	echo $LIST
	test -n "$LIST" || return
	if [ "$DISTRIB_ID" = "Ubuntu" ] ; then
		sudo dpkg -i $LIST $FORCE
	else
		if [ -n "$INITIAL" ] ; then
			sudo apt-get install $LIST
		else
			rpmU $LIST $FORCE
		fi
	fi
}

#############
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

TARGETPATH=$WINEPUB_PATH/$PROJECTVERSION/WINE/$SYSTEM
get_version_release

if cd $TARGETPATH ; then
	pwd

	LIST=
	for i in $BUILDNAME ; do
		pkg_is_installed $i && LIST="$LIST $i[-_]$VERSION-*$RELEASE[._]*.$EXT"
	done

	for i in lib$BUILDNAME-devel $BUILDNAME-gl $BUILDNAME-twain ; do
		pkg_is_installed $i && LIST="$LIST extra/$i[-_]$VERSION-*$RELEASE[._]*.$EXT"
	done

	install_pkg
fi

#############
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
