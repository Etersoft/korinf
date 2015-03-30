#!/bin/sh
# 2005, 2006, 2007, 2008 (c) Etersoft http://etersoft.ru
# Author: Vitaly Lipatov <lav@etersoft.ru>
# GNU Public License version 3

#
# load common functions, compatible with local and installed script
. `dirname $0`/../share/eterbuild/korinf/common
kormod korinf

# Неправильно вызывать несколько раз подряд (переопределение переменных)
(build_project /var/ftp/pub/Etersoft/RX@Etersoft nx "" $@)
(build_project /var/ftp/pub/Etersoft/RX@Etersoft rx-etersoft "" $@)
(build_project /var/ftp/pub/Etersoft/RX@Etersoft opennx "" $@)
(build_project /var/ftp/pub/Etersoft/RX@Etersoft nxsadmin "" $@)
