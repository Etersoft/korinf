#!/bin/sh
# 2005, 2006, 2007, 2008 (c) Etersoft http://etersoft.ru
# Author: Vitaly Lipatov <lav@etersoft.ru>
# GNU Public License version 3

#
# load common functions, compatible with local and installed script
. `dirname $0`/../share/eterbuild/korinf/common
kormod korinf

NAME=wine-etersoft

MAINFILES="$NAME[-_][0-9] $NAME-gl"
EXTRAFILES="$NAME-twain lib$NAME-devel"

# Hack for WINE@Etersoft 5.x
# see korinf/robot/funcs/build
if [ "$2" = "5.x" ] || [ "$3" = "5.x" ]  || [ "$2" = "5" ] || [ "$3" = "5" ] ; then
    MAINFILES="$NAME[-_][0-9] $NAME-full[-_][0-9] $NAME-programs[-_][0-9] lib$NAME[-_][0-9] lib$NAME-gl"
    EXTRAFILES="lib$NAME-twain lib$NAME-devel"
fi

build_project $WINEPUB_PATH $NAME WINE $@
