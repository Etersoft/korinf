#!/bin/bash
# 2007 (c) Etersoft http://etersoft.ru
# Author: Lunar Child <luch@etersoft.ru>
# GNU Public License
#
#

# например, wine-etersoft
PACKAGE="$1"
# например, 1.0.8
WINENUMVERSION="$2"
# например, network
# например, EEEE-C0DE
ETERREGNUM="$3"
SOURCEURL=$4
BUILDSRPM=$5
SRPM=`basename $BUILDSRPM`
PATCH="/usr/bin/patch"
WGET="/usr/bin/wget"
TAR="/usr/bin/gnu/tar"
PATH="/opt/csw/bin:/usr/sbin:/usr/bin:/usr/bin/gnu/bin:"
TMPPATH="/tmp/wine"
MAKE="gmake -j2"
ARCH=`arch`
[ -x $PATCH ] || exit 1
[ -x $WGET ] || exit 1
[ -x $TAR ] || exit 1

BASEVER="1.0.9" #hack for error in publish tarballs
if [ $WINENUMVERSION = 'current' ] ; then
    WINENUMVERSION=$BASEVER
fi

export PACKAGE
PRODUCT=`echo $PACKAGE | sed 's/wine-etersoft-\(.*\)/\1/g'`
echo "We get $PRODUCT to build"

package_info() {
#gen pkg filelist
	cd $DESTDIR
	pkgproto . >> $TMPPATH/prototype
#mv prototype to pkgdir. если генерить сразу в нужное место, список попадет в pkglist
	mv $TMPPATH/prototype $DESTDIR
#fix owner in pkg filelist
	subst 's| builder | root |g' $DESTDIR/prototype
	subst 's| other| root|g' $DESTDIR/prototype
#create pkginfo
	echo "PKG=$1" > $DESTDIR/pkginfo
	echo "NAME=Wine Is Not Emulator + many patches from Etersoft company." >> $DESTDIR/pkginfo
	echo "ARCH=$ARCH" >> $DESTDIR/pkginfo
	echo "VERSION=$WINENUMVERSION-$RELEASE" >> $DESTDIR/pkginfo
	echo "VENDOR=Etersoft" >> $DESTDIR/pkginfo
	echo "EMAIL=support@etersoft.ru" >> $DESTDIR/pkginfo
	echo "CATEGORY=system" >> $DESTDIR/pkginfo
	echo "BASEDIR=/" >> $DESTDIR/pkginfo
#include pkg info
	echo "i pkginfo=$DESTDIR/pkginfo" >> $DESTDIR/prototype
#make pkgmap
	cd $DESTDIR
	mkdir $TMPPATH/ready/
	pkgmk -o -r $DESTDIR -d $TMPPATH/ready/
}

pack_pkg() {
	if [ "$1" = "wine-etersoft-public" ] ; then
	    pkgtrans -so $TMPPATH/ready $1-"$VER"_"$RELEASE".$ARCH.pkg $1
	    gzip -9 $TMPPATH/ready/$1-"$VER"_"$RELEASE".$ARCH.pkg
	else
	    pkgtrans -so $TMPPATH/ready $1-"$WINENUMVERSION"_"$RELEASE".$ARCH.pkg $1
	    gzip -9 $TMPPATH/ready/$1-"$WINENUMVERSION"_"$RELEASE".$ARCH.pkg
	fi
}

upack_src() {
    $TAR xjf $1.tar.bz2
}

get_source() {
    $WGET $SOURCEURL/$SRPM
    rpm2cpio $SRPM > $PACKAGE.cpio
    cpio -d -i < $PACKAGE.cpio
}
#################################################################
#				BODY				#
#################################################################
##############################WINE-ETERSOFT######################

# Подготовка необходимых путей.
rm -rf $TMPPATH/*
mkdir $TMPPATH/
cd $TMPPATH/
DESTDIR="$TMPPATH/$PACKAGE"
##############################WINE-PUBLIC########################
if [ "$PACKAGE" = "wine-etersoft-public" ] ; then
    #Качаем исходники и распаковываем.
    echo "Building $PACKAGE from $SOURCEURL"
    get_source
    VER=`cat wine.spec | grep Version | sed 's/Version: //g'`
    RELEASE=`cat wine.spec | grep Release | sed 's/Release: alt//g'`
    upack_src wine-$WINENUMVERSION || exit 1
    #патчим wine.
    cd wine-$WINENUMVERSION
    $PATCH -p0 < etersoft/wine-etersoft.patch || exit 1
   #Компилируем wine.
    echo "$MAKE wine with patches"
    ./configure --prefix=/usr || exit 1
    $MAKE depend || exit 1
    $MAKE || exit 1
    mkdir -p $DESTDIR
    echo "$MAKE install to $DESTDIR"
    $MAKE install DESTDIR="$DESTDIR" || exit 1
    echo "$MAKE install ETERSOFT WINE utils to $DESTDIR"
    cd $TMPPATH/wine-$VER/etersoft
    $MAKE install prefix=$DESTDIR/usr initdir=$DESTDIR/etc/init.d sysconfdir=$DESTDIR/etc MKDIRPROG='mkdir -p' || exit 1
   #готовимся к созданию пакета (генерим необходимые файлы)
    package_info $PACKAGE
    pack_pkg $PACKAGE
else
##############################WINE-PVT###########################
    echo "Building $PACKAGE from $SOURCEURL"
    get_source
    upack_src $PACKAGE-$WINENUMVERSION
    RELEASE=`cat $PACKAGE.spec | grep Release | sed 's/Release: alt//g'`
# Компилируем.
    cd $PACKAGE-$WINENUMVERSION
    ./configure --prefix=/usr --sysconfdir=/etc --with-$PRODUCT --with-regnum=$ETERREGNUM || exit 1
    $MAKE || exit 1
    mkdir -p $DESTDIR
    echo "$MAKE install to $DESTDIR"
    $MAKE install DESTDIR="$DESTDIR" initdir="$DESTDIR/etc/init.d" || exit 1
# Готовимся к созданию пакета (генерим необходимые файлы)
    package_info $PACKAGE
    pack_pkg $PACKAGE
fi
