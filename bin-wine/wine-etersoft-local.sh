#!/bin/sh
# 2005, 2006, 2007, 2008 (c) Etersoft http://etersoft.ru
# Author: Vitaly Lipatov <lav@etersoft.ru>
# GNU Public License version 3

#
# load common functions, compatible with local and installed script
. `dirname $0`/../share/eterbuild/korinf/common
kormod korinf

export ALLOWPUBLICDEBUG=0

ver="$3"
case $ver in
    -*)
        ver="$2"
        ;;
esac

[ -n "$ver" ] || ver="7"


case $ver in
    1.0.12*)
        ver=1
        ;;
    2*)
        ver=2
        ;;
    5*)
        ver=5
        ;;
    6*)
        ver=6
        ;;
    7*)
        ver=7
        ;;
esac

KORINFMODULE=wine-$ver


build_project $WINEETER_PATH wine-etersoft-local WINE-Local $@

