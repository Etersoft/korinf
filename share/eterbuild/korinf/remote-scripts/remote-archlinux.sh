#!/bin/sh
# 2007 (c) Etersoft http://etersoft.ru
# Author: Vitaly Lipatov <lav@etersoft.ru>
# GNU Public License

# Internal build script for Gentoo
# positional parameters
PACKAGE="$1"
WINENUMVERSION="$2"
ETERREGNUM="$4"
SOURCEURL="$5"

echo "Start with PACKAGE: $PACKAGE WINENUMVERSION: $WINENUMVERSION ETERREGNUM: $ETERREGNUM, SOURCEURL - $SOURCEURL"
mkdir -p /home/lav/abs/$PACKAGE
cd /home/lav/abs/$PACKAGE || exit 1

# remove old files
rm -rf $PACKAGE || exit 1
rm -f /home/lav/abs/$PACKAGE/$PACKAGE-*
rm -f /home/lav/abs/$PACKAGE/$PACKAGE*.tbz2

# get ebuild file
portfile="archlinux-$PACKAGE.tar.bz2"
#porturl="ftp://server/$CAT/Etersoft/WINE@Etersoft-$WINENUMVERSION/sources/$portfile"
porturl="$SOURCEURL/$portfile"
rm -f $portfile && wget $porturl && tar xvfj $portfile || exit 1

# do not export PACKAGE here
export WINENUMVERSION
mkdir -p /home/lav/abs/$PACKAGE/src || exit 1
cd /home/lav/abs/$PACKAGE && makepkg || exit 1

exit 0
