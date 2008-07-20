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
mkdir -p /usr/portage/app-emulation
cd /usr/portage/app-emulation || exit 1

[ -n "$PRODUCT" ] && EPACKAGE=$PACKAGE-$PRODUCT || EPACKAGE=$PACKAGE

sudo chown -R builder:portage /usr/portage/app-emulation/ || { echo "Cannot change owner" ; exit 1 ; }

# remove old files
rm -rf $EPACKAGE || exit 1
rm -f /usr/portage/distfiles/$PACKAGE-*
rm -f /usr/portage/packages/All/$EPACKAGE*.tbz2

# get ebuild file
portfile="gentoo-$EPACKAGE.tar.bz2"
#porturl="ftp://server/$CAT/Etersoft/WINE@Etersoft-$WINENUMVERSION/sources/$portfile"
porturl="$SOURCEURL/$portfile"
rm -f $portfile && wget $porturl && tar xvfj $portfile || exit 1

#sed -i 's|@ETERREGNUM@|${ETERREGNUM}|g' $EPACKAGE/*.ebuild
#export ETERREGNUM WINENUMVERSION
# Hack:
sed -i "1iETERREGNUM=$ETERREGNUM" $EPACKAGE/*.ebuild || exit 1
sed -i "1iWINENUMVERSION=$WINENUMVERSION" $EPACKAGE/*.ebuild || exit 1
# do not export PACKAGE here
# --buildpkgonly 
export WINENUMVERSION
if [ -e /usr/bin/sudo ] ; then 
    FEATURES="nostrip noclean" sudo emerge --verbose --digest --buildpkg $EPACKAGE || exit 1
else 
    FEATURES="nostrip noclean" emerge --verbose --digest --buildpkg $EPACKAGE || exit 1
fi

exit 0
