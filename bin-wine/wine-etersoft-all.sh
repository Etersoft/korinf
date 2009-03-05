#!/bin/sh
# 2005, 2006, 2007, 2008 (c) Etersoft http://etersoft.ru
# Author: Vitaly Lipatov <lav@etersoft.ru>
# GNU Public License version 3

#
# load common functions, compatible with local and installed script
. `dirname $0`/../share/eterbuild/korinf/common
kormod korinf

# Не отдавать с таким кодом
#ETERREGNUM=EEEE-C0DE
# ETERREGNUM=EEEE-0003

build_project $WINEETER_PATH wine-etersoft-local WINE-Local $@

build_project $WINEETER_PATH wine-etersoft-network WINE-Network $@

build_project $WINEETER_PATH wine-etersoft-networklite WINE-NetworkLite $@

build_project $WINEETER_PATH wine-etersoft-networkunique WINE-NetworkUnique $@

build_project $WINEETER_PATH wine-etersoft-sql WINE-SQL $@

build_project $WINEETER_PATH wine-etersoft-sqlunique WINE-SQLUnique $@
