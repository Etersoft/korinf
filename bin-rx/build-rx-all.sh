#!/bin/sh
# 2005, 2006, 2007, 2008 (c) Etersoft http://etersoft.ru
# Author: Vitaly Lipatov <lav@etersoft.ru>
# GNU Public License version 3

#
# load common functions, compatible with local and installed script
. `dirname $0`/../share/eterbuild/korinf/common
kormod korinf

export KORINFMODULE=rx

# Неправильно вызывать несколько раз подряд (переопределение переменных)
(build_project /var/ftp/pvt/Etersoft/RX@Etersoft nx-libs "" $@)
(build_project /var/ftp/pvt/Etersoft/RX@Etersoft prunner "" $@)
(build_project /var/ftp/pvt/Etersoft/RX@Etersoft nxssh "" $@)
(build_project /var/ftp/pvt/Etersoft/RX@Etersoft rx-etersoft "" $@)
(build_project /var/ftp/pvt/Etersoft/RX@Etersoft rx-etersoft-smartcard "" $@)
(build_project /var/ftp/pvt/Etersoft/RX@Etersoft rx-etersoft-pcsc "" $@)
(build_project /var/ftp/pvt/Etersoft/RX@Etersoft rxclient "" $@)
