#!/bin/sh

VEREL=1.4.1-alt1
WINENUMVERSION=1.0.9
TOPDIR=/var/ftp/pub/ALTLinux/Sisyphus
cp -f ~/RPM/RPMS/etersoft-build-utils-$VEREL.noarch.rpm $TOPDIR/i586/RPMS.ourside
cp -f /var/ftp/pub/Etersoft/WINE@Etersoft/current/sources/etersoft-build-utils-$VEREL.src.rpm \
	/var/ftp/pub/Etersoft/WINE@Etersoft/$WINENUMVERSION/sources/
#umask 0
genbasedir -v --topdir=$TOPDIR i586 ourside
chmod a+r $TOPDIR/i586/base/*ourside*

