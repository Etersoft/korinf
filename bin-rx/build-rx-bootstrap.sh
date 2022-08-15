#!/bin/sh
# 2005, 2006, 2007, 2008 (c) Etersoft http://etersoft.ru
# Author: Vitaly Lipatov <lav@etersoft.ru>
# GNU Public License version 3

#
# load common functions, compatible with local and installed script
. `dirname $0`/../share/eterbuild/korinf/common
kormod korinf

export KORINFMODULE=rx

SKIPBUILDLIST="OpenSolaris Windows"

MAINFILES="nx-libs[-_][0-9] nxproxy[-_][0-9] nxagent[-_][0-9]"
EXTRAFILES="nx-libs-devel[-_][0-9]"
(build_project /var/ftp/pvt/Etersoft/RX@Etersoft nx-libs "" $@) || exit

unset MAINFILES EXTRAFILES

(build_project /var/ftp/pvt/Etersoft/RX@Etersoft prunner "" $@) || exit
(build_project /var/ftp/pvt/Etersoft/RX@Etersoft nxssh "" $@) || exit

if [ "$2" = "-b" ] || [ "$2" = "-B" ] ; then
    exit
fi

(build_project /var/ftp/pvt/Etersoft/RX@Etersoft rx-etersoft "" $@) || exit
#(build_project /var/ftp/pvt/Etersoft/RX@Etersoft rx-etersoft-smartcard "" $@)
#(build_project /var/ftp/pvt/Etersoft/RX@Etersoft rx-etersoft-pcsc "" $@)
(build_project /var/ftp/pvt/Etersoft/RX@Etersoft rxclient "" $@) || exit
