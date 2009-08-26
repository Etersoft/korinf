#!/bin/sh
# 2007 (c) Etersoft http://etersoft.ru
# Author: Vitaly Lipatov <lav@etersoft.ru>
# GNU Public License

# Internal build script for Gentoo
# positional parameters
COMMAND=$1
PACKAGE="$2"
#RPMSDIR="$3"
SOURCEURL="$3"

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


build_gentoo()
{
        RPMBUILDNODEPS="--nodeps"
        RPMBUILDROOT="/home/$INTUSER/RPM/BUILD/$PACKAGE-$PKGVERSION"
        # FIXME: x86_64 support
        BUILDARCH=i586
        rpmbuild -v --rebuild $RPMBUILDNODEPS --buildroot $RPMBUILDROOT $SRPMNAME --target $BUILDARCH
}

#convert to tar.gz
convert_gentoo()
{
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

gen_ebuild()
{
        # FIXME: how to get build package name?
        #PKGNAME=`querypackage "$SRPMNAME" NAME`
        # FIXME: problem with various version
	LOCUSER=korinfer
	WORKDIR=/home/$LOCUSER/tmp
	RPMSDIR=/home/$LOCUSER/RPM/RPMS
        BUILTRPM=$(ls -1 $RPMSDIR/*.rpm | grep $PACKAGE | tail -n1)

	mkdir -p $WORKDIR
	cd $WORKDIR

	EBUILDVERSION=`querypackage "$BUILTRPM" VERSION`
	EBUILDRELEASE=`querypackage "$BUILTRPM" RELEASE`
	EBUILDFILE=${WORKDIR}/${PACKAGE}-${EBUILDVERSION}-${EBUILDRELEASE}.ebuild
	export $EBUILDFILE

	echo "# Copyright 1999-2007 Gentoo Foundation" > $EBUILDFILE
	echo "# Distributed under the terms of the GNU General Public License v2" >> $EBUILDFILE
	echo '# $Header: $' >> $EBUILDFILE

        DESCRIPTION=`querypackage "$BUILTRPM" DESCRIPTION`
	echo "DESCRIPTION=$DESCRIPTION" >> $EBUILDFILE
	HOMEPAGE=`querypackage "$BUILTRPM" URL`
	echo "HOMEPAGE=$HOMEPAGE" >> $EBUILDFILE

	#FIXME: how to define SRC_URI
	TARGET="tar.bz2"
	SRC_URI="http://updates.etersoft.ru/pub/Etersoft/$PRODUCT/last/\${P}.${TARGET}"
	echo "SRC_URI=$SRC_URI" >> $EBUILDFILE
	LICENSE=`querypackage "$BUILTRPM" LICENSE`
	echo "LICENSE=$LICENSE" >> $EBUILDFILE
	echo 'SLOT="0"' >> $EBUILDFILE
	echo 'KEYWORDS="-* x86 amd64"' >> $EBUILDFILE
	echo >> $EBUILDFILE
	echo "src_unpack() {" >> $EBUILDFILE
	echo 'unpack ${A}' >> $EBUILDFILE
	echo "}" >> $EBUILDFILE
	echo >> $EBUILDFILE
	echo "src_install() {" >> $EBUILDFILE
	echo 'cp -pR "${WORKDIR}" "${D}"' >> $EBUILDFILE
	echo "}" >> $EBUILDFILE

	cp $EBUILDFILE $RPMSDIR

        #get file hierarchy
#	cp $BUILTRPM ${WORKDIR}/${PACKAGE}
#        rpm2cpio $BUILTRPM | cpio -dimv || fatal "error with rpm2cpio"
#        rm -f $BUILTRPM

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
