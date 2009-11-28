#!/bin/sh
# 2005, 2006, 2007, 2008 (c) Etersoft http://etersoft.ru
# Author: Vitaly Lipatov <lav@etersoft.ru>
# GNU Public License version 3

#
# load common functions, compatible with local and installed script
. `dirname $0`/../share/eterbuild/korinf/common
kormod korinf

MAINFILES="wine[-_][0-9] libwine[-_][0-9]"
EXTRAFILES="libwine-[!0-9]"

build_project $WINEPUB_PATH wine WINE $@
