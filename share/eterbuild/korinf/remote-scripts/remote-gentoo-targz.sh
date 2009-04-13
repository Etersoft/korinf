#!/bin/sh
# 2007 (c) Etersoft http://etersoft.ru
# Author: Vitaly Lipatov <lav@etersoft.ru>
# GNU Public License

# Internal build script for Gentoo
# positional parameters
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
#cp *$BUILDNAME* $PORTAGEDIR/packages/All

exit 0
