#!/bin/sh
# 2006 (c) Etersoft www.etersoft.ru
# Public domain
#
#Usage:
#user_manage.sh {add, delete, change} NEWUSER NEWGROUP OLDUSER
#


# load common functions, compatible with local and installed script

RPMDIR=/srv/yurifil/RPM/
CIFS_SRPMDIR=/var/ftp/pub/Etersoft/LINUX@Etersoft/Boxes/etercifs/SRPMS.default
CIFS_FTPDIR=/var/ftp/pub/Etersoft/CIFS@Etersoft

CIFS_VERSION=$1
ALT_RELEASE=$2
CIFS_RELEASE=$CIFS_VERSION-$ALT_RELEASE
echo Releasing etercifs-$CIFS_RELEASE
echo
echo Copying SRPMs
cp $CIFS_SRPMDIR/etercifs-$CIFS_RELEASE* $RPMDIR/SRPMS
cp $CIFS_SRPMDIR/dkms-etercifs-$CIFS_RELEASE* $RPMDIR/SRPMS
echo "Done"
echo
echo Building SRPMS without lzma:
cd $RPMDIR/SRPMS
rpm -i etercifs-$CIFS_RELEASE* dkms-etercifs-$CIFS_RELEASE*
cd $RPMDIR/SPECS
rpmbs -z etercifs* dkms-etercifs*
mkdir -p $CIFS_FTPDIR/$CIFS_VERSION/sources
echo Done with building
echo
echo Copying to FTP
cp $RPMDIR/SRPMS/*etercifs-$CIFS_RELEASE* $CIFS_FTPDIR/$CIFS_VERSION/sources
echo Done