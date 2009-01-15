#!/bin/sh
# 2007 (c) Etersoft http://etersoft.ru
# Author: Vitaly Lipatov <lav@etersoft.ru>
# GNU Public License

# Internal build script for ArchLinux

#testing

#end of testing

PACKAGE=$1
BUILDNAME=$2

querypackage()
{
	rpmquery -p --queryformat "%{$2}" $1
}


make_pkgbuild()
{
        sed -i "1cpkgname=$PACKAGENAME" $PKGDIR/PKGBUILD
        sed -i "2cpkgver=$PKGVERSION" $PKGDIR/PKGBUILD
        sed -i "3cpkgrel=$PKGREL" $PKGDIR/PKGBUILD
        sed -i "5curl=$PKGURL" $PKGDIR/PKGBUILD
        sed -i "6carch=(i686)" $PKGDIR/PKGBUILD
        sed -i "7clicense=('$LICENSE')" $PKGDIR/PKGBUILD
# inserting dependencies
#       sed -i "7adepends="  $BUILDERHOME/abs/$PACKAGE/PKGBUILD
#       sed -i ""  $BUILDERHOME/abs/$PACKAGE/PKGBUILD
}


BUILDERHOME=/home/lav
ABSDIR=$BUILDERHOME/abs
PKGDIR=$ABSDIR/$BUILDNAME

# get draft PKGBUILD file
mkdir -p $ABSDIR
cd $ABSDIR
portfile="archlinux-PKGBUILD.tar.bz2"
rm -f $ABSDIR/$portfile && cp /var/local/abs/$portfile $ABSDIR && tar xvfj $portfile || exit 1

cd $BUILDERHOME/RPM/RPMS
for i in *$BUILDNAME*.rpm
do
    # setting up variables
    PACKAGENAME=`querypackage "$i" NAME`
    PKGVERSION=`querypackage "$i" VERSION`
    PKGREL=`querypackage "$i" RELEASE`
    PKGURL=`querypackage "$i" URL`
    # doesn't work if ARCH != i686
    ARCH=i686 #`querypackage "$i" ARCH`
    LICENSE=`querypackage "$i" LICENSE`

#    PKGDIR=$ABSDIR/$PACKAGENAME

    # remove old files
    rm -f $PKGDIR

    # extract binaries
    mkdir -p $PKGDIR/src
    cp $i $PKGDIR/src
    cd $PKGDIR/src || exit 1
    rpmextract.sh $i
    rm -f *.rpm

    # make PKGBUILD
    cd $PKGDIR
    cp $ABSDIR/PKGBUILD.in PKGBUILD
    make_pkgbuild

    # build package
    makepkg
    rm -f PKGBUILD

    cd $BUILDERHOME/RPM/RPMS
done

exit 0
