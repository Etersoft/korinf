#!/bin/sh
# 2005, 2006, 2007, 2008 (c) Etersoft http://etersoft.ru
# Author: Vitaly Lipatov <lav@etersoft.ru>
# GNU Public License version 3
#

# load common functions, compatible with local and installed script
. `dirname $0`/../share/eterbuild/korinf/common
kormod korinf

#VERSION=7.x
VERSION=7-unstable
#[ -n "$1" ] && VERSION="$1"

export KORINFMODULE=wine-7

NAME=wine-gecko
MAINFILES="$NAME[-_][0-9]"
(build_project $WINEPUB_PATH/$VERSION $NAME "WINE" $@)

NAME=wine-mono
MAINFILES="$NAME[-_][0-9]"
(build_project $WINEPUB_PATH/$VERSION $NAME "WINE" $@)

NAME=winetricks
MAINFILES="$NAME[-_][0-9]"
(build_project $WINEPUB_PATH/$VERSION $NAME "WINE" $@)
