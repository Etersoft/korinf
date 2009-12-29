#!/bin/sh
# 2007 (c) Etersoft http://etersoft.ru
# Author: Vitaly Lipatov <lav@etersoft.ru>
# GNU Public License

# Internal build script for Gentoo
# positional parameters
COMMAND=$1
PACKAGE="$2"
DESTURL="$3"
#SOURCEURL="$3"
#DESTURL="$5"


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

gen_ebuild()
{
        # FIXME: problem with various version
	LOCUSER=korinfer
	WORKDIR=/home/$LOCUSER/tmp
	RPMSDIR=/home/$LOCUSER/RPM/RPMS
        BUILTRPM=$(ls -1 $RPMSDIR/*.rpm | grep $PACKAGE | tail -n1)
        BUILTTARS=$(ls -1 $RPMSDIR | grep tar.bz2 | grep $PACKAGE)
#        BUILTRPM=$(ls -1 $RPMSDIR/*.rpm | grep ^$PACKAGE)
	[ -n "$BUILTRPM" ] || fatal "BUILTRPM var is empty"
	test -r ${BUILTRPM} || return 1
	mkdir -p $WORKDIR
	cd $WORKDIR

	EBUILDVERSION=`querypackage "$BUILTRPM" VERSION`
	EBUILDRELEASE=`querypackage "$BUILTRPM" RELEASE`
	EBUILDARCH=`querypackage "$BUILTRPM" ARCH`
	#test: emerge doesn't work with release
	EBUILDFILE=${WORKDIR}/${PACKAGE}-${EBUILDVERSION}.ebuild
	export $EBUILDFILE

	#add quotation marks to description
        DESCRIPTION=`querypackage "$BUILTRPM" SUMMARY`
        DESCRIPTION="${DESCRIPTION}"
	HOMEPAGE=`querypackage "$BUILTRPM" URL`
	LICENSE=`querypackage "$BUILTRPM" LICENSE`
	#FIXME: how to define SRC_URI
	TARGET="tar.bz2"

#	for i in $BUILTRPMS ; do
#	    PN=`querypackage $i NAME`
#	    PV=`querypackage $i VERSION`
#	    MY_R=`querypackage $i RELEASE`
#	    MY_ARCH=`querypackage $i ARCH`
#	    #SRC_URI="$SRC_URI $DESTURL/\${PN}-\${PV}-\${MY_R}.\${MY_ARCH}.${TARGET}"
#	    SRC_URI="$SRC_URI $DESTURL/${PN}-${PV}-${MY_R}.${MY_ARCH}.${TARGET}"
#	done
	for i in $BUILTTARS ; do
	    SRC_URI="$SRC_URI \$BASE_URI/$i"
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
SRC_URI=$SRC_URI
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

        # create package with the PACKAGE name (not src.rpm name)
#        rm -f ../$TARGETPKG
#        ebuild $EBUILDFILE package || fatal
#        cd -

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
		gen_ebuild
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
