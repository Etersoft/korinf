#!/bin/sh
# 2005, 2006, 2007, 2008 (c) Etersoft http://etersoft.ru
# Author: Vitaly Lipatov <lav@etersoft.ru>
# GNU Public License version 3

#
# load common functions, compatible with local and installed script
. `dirname $0`/../share/eterbuild/korinf/common
kormod korinf

ASCONPATH=/var/ftp/pub/download/WINE@Etersoft-CAD

build_project $ASCONPATH wine-etersoft-cad "" $@

NAME=wine-etersoft

MAINFILES="$NAME[-_][0-9] $NAME-gl[-_][0-9]"
EXTRAFILES="$NAME-twain[-_] lib$NAME-devel"

build_project $ASCONPATH $NAME "" $@

unset MAINFILES
unset EXTRAFILES
build_project $ASCONPATH haspd "" $@
