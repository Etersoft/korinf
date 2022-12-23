#!/bin/sh
# 2005, 2006, 2007, 2008 (c) Etersoft http://etersoft.ru
# Author: Vitaly Lipatov <lav@etersoft.ru>
# GNU Public License version 3

#
# load common functions, compatible with local and installed script
. `dirname $0`/../share/eterbuild/korinf/common
kormod korinf

NAME=wine-etersoft
NAME32=wine32-etersoft

. `dirname $0`/functions

set_ver "$@"

case "$ver" in
    1|2)
        MAINFILES="$NAME[-_][0-9] $NAME-gl"
        EXTRAFILES="$NAME-twain lib$NAME-devel"
        ;;
    5|6)
        MAINFILES="$NAME[-_][0-9] $NAME-full[-_][0-9] $NAME-programs[-_][0-9] lib$NAME[-_][0-9] lib$NAME-gl"
        EXTRAFILES="lib$NAME-twain lib$NAME-devel"
        ;;
    7*|8*)
        MAINFILES="$NAME32[-_][0-9] $NAME-common[-_][0-9] $NAME32-full[-_][0-9] $NAME-programs[-_][0-9]"
        EXTRAFILES="$NAME32-devel $NAME-ping[-_][0-9]"
        ;;
     *)
        fatal "Unknown ver $ver"
        ;;
esac

build_project $WINEPUB_PATH $NAME WINE $@

