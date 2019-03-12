#!/bin/sh
# 2005, 2006, 2007, 2008 (c) Etersoft http://etersoft.ru
# Author: Vitaly Lipatov <lav@etersoft.ru>
# GNU Public License version 3
#

# load common functions, compatible with local and installed script
. `dirname $0`/../share/eterbuild/korinf/common
kormod korinf

NAME=wine

MAINFILES="$NAME[-_][0-9] $NAME-full[-_][0-9] $NAME-programs[-_][0-9] lib$NAME[-_][0-9] lib$NAME-gl lib$NAME-twain lib$NAME-devel"

build_project $WINEPUB_PATH/../Wine-staging $NAME "" $@
