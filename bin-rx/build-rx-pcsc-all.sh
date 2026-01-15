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

# Постянно теряются пакеты rxclient-pcsc(подпакет rx-etersoft-pcsc)
# и rx-etersoft-pcsc-driver. После ручного перезапуска снова появляются

(build_project /var/ftp/pvt/Etersoft/RX@Etersoft rx-etersoft-pcsc "" $@)
(build_project /var/ftp/pvt/Etersoft/RX@Etersoft rx-etersoft-pcsc-driver "" $@)
