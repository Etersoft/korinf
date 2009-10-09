#!/bin/bash
# 2007 (c) Etersoft http://etersoft.ru
# Author: Lunar Child <luch@etersoft.ru>
# GNU Public License
#
#
# TODO: WINENUMVERSION is not used now

# например, wine-etersoft
PACKAGE="$1"

SOURCEURL=$2

querypackage()
{
        rpmquery -p --queryformat "%{$2}" $1
}

package_info() {
#gen pkg filelist
	cd $WORKDIR
	pkgproto . >> $WORKDIR/prototype
#mv prototype to pkgdir. если генерить сразу в нужное место, список попадет в pkglist
	mv $WORKDIR/prototype $DESTDIR
#fix owner in pkg filelist
	subst 's| korinfer | root |g' $DESTDIR/prototype
	subst 's| builder | root |g' $DESTDIR/prototype
	subst 's| other| root|g' $DESTDIR/prototype
#create pkginfo
	echo "PKG=$1" > $DESTDIR/pkginfo
	echo "NAME=$SUMMARY" >> $DESTDIR/pkginfo
	echo "ARCH=$ARCH" >> $DESTDIR/pkginfo
	echo "VERSION=$VER" >> $DESTDIR/pkginfo
	echo "VENDOR=Etersoft" >> $DESTDIR/pkginfo
	echo "EMAIL=support@etersoft.ru" >> $DESTDIR/pkginfo
	#TODO: fix for various categories
	echo "CATEGORY=system" >> $DESTDIR/pkginfo
	echo "BASEDIR=/" >> $DESTDIR/pkginfo
#include pkg info
	echo "i pkginfo=$DESTDIR/pkginfo" >> $DESTDIR/prototype
#make pkgmap
	cd $DESTDIR
	mkdir $DESTDIR/ready/
	pkgmk -o -r $DESTDIR -d $DESTDIR/ready/
}

pack_pkg() {
	pkgtrans -so $DESTDIR/ready $1-"$VER"_"$RELEASE".$ARCH.pkg $1
	gzip -9 $DESTDIR/ready/$1-"$VER"_"$RELEASE".$ARCH.pkg
}

get_bin() {
        #get file hierarchy
    cp $BUILTRPM ${WORKDIR}/${PACKAGE}
    rpm2cpio $BUILTRPM | cpio -dimv || fatal "error with rpm2cpio"
    rm -f $BUILTRPM
}

#################################################################
#				BODY				#
#################################################################

# Подготовка необходимых путей.
#TMPPATH="/tmp/${PACKAGE}"
DESTDIR="/tmp/$PACKAGE"
WORKDIR="/tmp/$PACKAGE/work"
rm -rf $DESTDIR
mkdir $DESTDIR
cd $DESTDIR/
RPMSDIR=/home/korinfer/RPM/RPMS
##############################WINE-PUBLIC########################
#Качаем исходники и распаковываем.
echo "Building $PACKAGE from $SOURCEURL"
get_bin
#Set variables
BUILTRPM=$(ls -1 $RPMSDIR/*.rpm | grep $PACKAGE | tail -n1)
VER=`querypackage "$BUILTRPM" VERSION`
RELEASE=`querypackage "$BUILTRPM" RELEASE`
SUMMARY=`querypackage "$BUILTRPM" SUMMARY`
ARCH=`arch`

get_bin
#готовимся к созданию пакета (генерим необходимые файлы)
package_info $PACKAGE
pack_pkg $PACKAGE
