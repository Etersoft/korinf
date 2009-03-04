#!/bin/sh
# 2007 (c) Etersoft http://etersoft.ru
# Author: Vitaly Lipatov <lav@etersoft.ru>
# GNU Public License

# Internal build script for Gentoo
# positional parameters
PACKAGE="$1"
ETERREGNUM="$2"
SOURCEURL="$3"

WORKDIR=/home/$INTUSER/abs

echo "Start with PACKAGE: $PACKAGE ETERREGNUM: $ETERREGNUM, SOURCEURL - $SOURCEURL"
mkdir -p $WORKDIR/$PACKAGE
cd $WORKDIR/$PACKAGE || exit 1

# remove old files
rm -rf $PACKAGE || exit 1
rm -f $WORKDIR/$PACKAGE/$PACKAGE-*
rm -f $WORKDIR/$PACKAGE/$PACKAGE*.tbz2

# get ebuild file
portfile="archlinux-$PACKAGE.tar.bz2"
#porturl="ftp://server/$CAT/Etersoft/WINE@Etersoft-$WINENUMVERSION/sources/$portfile"
porturl="$SOURCEURL/$portfile"
rm -f $portfile && wget $porturl && tar xvfj $portfile || exit 1

# do not export PACKAGE here
mkdir -p $WORKDIR/$PACKAGE/src || exit 1
cd $WORKDIR/$PACKAGE && makepkg || exit 1

exit 0
