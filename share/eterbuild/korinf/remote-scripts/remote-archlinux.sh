#!/bin/sh
# 2007 (c) Etersoft http://etersoft.ru
# Author: Vitaly Lipatov <lav@etersoft.ru>
# GNU Public License

# Internal build script for Gentoo
# positional parameters
PACKAGE="$1"
WINENUMVERSION="$2"
PRODUCT="$3"
ETERREGNUM="$4"
SOURCEURL="$5"

echo "Start with PACKAGE: $PACKAGE WINENUMVERSION: $WINENUMVERSION PRODUCT: $PRODUCT ETERREGNUM: $ETERREGNUM, SOURCEURL - $SOURCEURL"
mkdir -p /home/lav/abs/$PACKAGE
cd /home/lav/abs/$PACKAGE || exit 1

[ -n "$PRODUCT" ] && EPACKAGE=$PACKAGE-$PRODUCT || EPACKAGE=$PACKAGE

# remove old files
rm -rf $EPACKAGE || exit 1
rm -f /home/lav/abs/$PACKAGE/$PACKAGE-*
rm -f /home/lav/abs/$PACKAGE/$EPACKAGE*.tbz2

# get ebuild file
portfile="archlinux-$EPACKAGE.tar.bz2"
#porturl="ftp://server/$CAT/Etersoft/WINE@Etersoft-$WINENUMVERSION/sources/$portfile"
porturl="$SOURCEURL/$portfile"
rm -f $portfile && wget $porturl && tar xvfj $portfile || exit 1

#sed -i 's|@ETERREGNUM@|${ETERREGNUM}|g' $EPACKAGE/*.ebuild
#export ETERREGNUM WINENUMVERSION

# Hack:
#sed -i "1iETERREGNUM=$ETERREGNUM" $EPACKAGE/*.ebuild || exit 1
#sed -i "1iWINENUMVERSION=$WINENUMVERSION" $EPACKAGE/*.ebuild || exit 1

# do not export PACKAGE here
export WINENUMVERSION
mkdir -p /home/lav/abs/$PACKAGE/src || exit 1
cd /home/lav/abs/$PACKAGE && makepkg || exit 1

exit 0
