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

build_project /var/ftp/pvt/Etersoft/RX@Etersoft nxssh "" $@
