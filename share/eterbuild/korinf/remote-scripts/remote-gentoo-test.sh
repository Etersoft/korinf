#!/bin/sh
# 2007 (c) Etersoft http://etersoft.ru
# Author: Vitaly Lipatov <lav@etersoft.ru>
# GNU Public License

# Internal build script for Gentoo
# positional parameters
COMMAND=$1
PACKAGE="$2"
ETERREGNUM="$3"
SOURCEURL="$4"

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

#convert to tar.gz
convert_gentoo()
{
PACKAGE="$1"
RPMSDIR="$3"

LOCUSER=korinfer
BUILDERHOME=/home/$LOCUSER
#PORTAGEDIR=/usr/local/portage
#TEMPDIR=$BUILDERHOME/tmp/$PACKAGE
#RPMDIR=$BUILDERHOME/RPM/BP

echo
echo "Changing to RPMSDIR=$RPMSDIR"
pushd $RPMSDIR
echo "Converting rpm to tar.gz"
rpm2targz *$BUILDNAME*
rm -f *$PACKAGE*.rpm

exit 0
}

build_gentoo()
{
        RPMBUILDNODEPS="--nodeps"
        RPMBUILDROOT="/home/$INTUSER/RPM/BUILD/$PACKAGE-$PKGVERSION"
        # FIXME: x86_64 support
        BUILDARCH=i586
        rpmbuild -v --rebuild $RPMBUILDNODEPS --buildroot $RPMBUILDROOT $SRPMNAME --target $BUILDARCH
}

gen_ebuild()
{
        # FIXME: how to get build package name?
        #PKGNAME=`querypackage "$SRPMNAME" NAME`
        # FIXME: problem with various version
	WORKDIR=/usr/portage/${GROUP}/${PACKAGE}
	RPMDIR=/home/$INTUSER/RPM/RPMS
	EBUILDFILE=${WORKDIR}/${PACKAGE}.ebuild
        BUILTRPM=$(ls -1 $RPMDIR/*.rpm | grep $PKGNAME | tail -n1)

	mkdir -p $WORKDIR
	cd $WORKDIR
	echo "# Copyright 1999-2007 Gentoo Foundation" > $EBUILDFILE
	echo "# Distributed under the terms of the GNU General Public License v2" >> $EBUILDFILE
	echo '# $Header: $' >> $EBUILDFILE

        DESCRIPTION=`querypackage "$BUILTRPM" DESCRIPTION`
	echo "DESCRIPTION=$DESCRIPTION" >> $EBUILDFILE
	HOMEPAGE=`querypackage "$BUILTRPM" URL`
	echo "HOMEPAGE=$HOMEPAGE" >> $EBUILDFILE
	#FIXME: how to define SRC_URI
	SRC_URI=""
	echo "SRC_URI=$SRC_URI" >> $EBUILDFILE
	LICENSE=`querypackage "$BUILTRPM" LICENSE`
	echo "LICENSE=$LICENSE`" >> $EBUILDFILE
	echo 'SLOT="0"' >> $EBUILDFILE
	echo 'KEYWORDS="-* x86 amd64"' >> $EBUILDFILE
	echo "src_install() {" >> $EBUILDFILE
	echo "cp -R "${WORKDIR}/${PACKAGE}" "${D}"" >> $EBUILDFILE
	echo "}" >> $EBUILDFILE

        #get file hierarchy
	cp $BUILTRPM ${WORKDIR}/${PACKAGE}
        rpm2cpio $BUILTRPM | cpio -dimv || fatal "error with rpm2cpio"
        rm -f $BUILTRPM

        # create package with the PACKAGE name (not src.rpm name)
        rm -f ../$TARGETPKG
        ebuild $EBUILDFILE package || fatal
        cd -
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
        "convert")
                convert_gentoo && gen_ebuild
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
