#!/bin/sh
# 2007 (c) Etersoft http://etersoft.ru
# Author: Vitaly Lipatov <lav@etersoft.ru>
# GNU Public License

# Internal build script for Gentoo
# positional parameters
COMMAND=$1
PACKAGE="$2"
DESTURL="$3"
SRPMNAME=$4
EXPMAINFILES="$5"
LOCUSER=korinfer

#FIXME: set package group to Gentoo option
GROUP=app-emulation

querypackage()
{
        rpmquery -p --queryformat "%{$2}" $1
}

fatal()
{
        echo $@ >&2
        exit 1
}

gen_ebuild_remote()
{
        # FIXME: problem with various version
	LOCUSER=korinfer
	WORKDIR=/home/$LOCUSER/tmp
	RPMSDIR=/home/$LOCUSER/RPM/RPMS
        BUILTRPM=$(ls -1 $RPMSDIR/*.rpm | grep $PACKAGE | tail -n1)
#        BUILTTARS=$(ls -1 $RPMSDIR | grep tar.bz2 | grep $PACKAGE)
	BUILTTARS=$(cd $RPMSDIR && ls -1 $EXPMAINFILES)
	[ -n "$BUILTRPM" ] || fatal "BUILTRPM var is empty"
	test -r ${BUILTRPM} || return 1
	mkdir -p $WORKDIR
	cd $WORKDIR

#Set variables that depend on RPM
#	EBUILDVERSION=`querypackage "$BUILTRPM" VERSION`
#	EBUILDRELEASE=`querypackage "$BUILTRPM" RELEASE`
#	EBUILDARCH=`querypackage "$BUILTRPM" ARCH`
#	HOMEPAGE=`querypackage "$BUILTRPM" URL`
#	LICENSE=`querypackage "$BUILTRPM" LICENSE`
#test: is SRPMNAME better for vars definitions?
	EBUILDVERSION=`querypackage "$SRPMNAME" VERSION`
	EBUILDRELEASE=`querypackage "$SRPMNAME" RELEASE`
	EBUILDARCH=`querypackage "$SRPMNAME" ARCH`
        DESCRIPTION=`querypackage "$SRPMNAME" SUMMARY`
	HOMEPAGE=`querypackage "$SRPMNAME" URL`
	LICENSE=`querypackage "$SRPMNAME" LICENSE`
#Add qoutation marks:
        DESCRIPTION=\"${DESCRIPTION}\"

#Set other variables
#test: emerge doesn't work with release
	EBUILDFILE=${WORKDIR}/${PACKAGE}-${EBUILDVERSION}.ebuild
	export $EBUILDFILE
	TARGET="tar.bz2"

#Add all built TARs to SRC_URI variable
	for i in $BUILTTARS ; do
	    SRC_URI="\$BASE_URI/$i $SRC_URI"
	done
	cat > $EBUILDFILE << EOF
# Copyright 1999-2009 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: $

MY_R=$EBUILDRELEASE
MY_ARCH=$EBUILDARCH
DESCRIPTION=$DESCRIPTION
HOMEPAGE=$HOMEPAGE

BASE_URI=$DESTURL
SRC_URI="$SRC_URI"
LICENSE=$LICENSE
SLOT="0"
KEYWORDS="-* x86 amd64"

src_unpack() {
unpack \${A}
}

src_install() {
cp -pR * "\${D}"
}
EOF

	cp $EBUILDFILE $RPMSDIR

# delete built RPM
	rm -rf $BUILTRPM

}

install_gentoo()
{
        emerge ../$TARGETPKG
}

clean_gentoo()
{
        echo "Cleaning..."
        rm -rf $WRKDIR
}

case $COMMAND in
        "build")
                build_gentoo
                ;;
        "generate")
		gen_ebuild_remote
                ;;
        "install")
                install_gentoo
                ;;
        "clean")
                clean_gentoo
                ;;
        *)
                fatal "Unknown command $COMMAND"
                ;;
esac
