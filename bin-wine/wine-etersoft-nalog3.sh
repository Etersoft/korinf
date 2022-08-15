#!/bin/sh
# 2005, 2006, 2007, 2008 (c) Etersoft http://etersoft.ru
# Author: Vitaly Lipatov <lav@etersoft.ru>
# GNU Public License version 3
#

# load common functions, compatible with local and installed script
. `dirname $0`/../share/eterbuild/korinf/common
kormod korinf

export KORINFMODULE=wine-5-nalog3

NAME=wine-etersoft

MAINFILES="$NAME[-_][0-9] $NAME-full[-_][0-9] $NAME-programs[-_][0-9] lib$NAME[-_][0-9] lib$NAME-gl lib$NAME-twain lib$NAME-devel"

(build_project $WINEETER_PATH/../WINE@Etersoft $NAME "" $@)
exit
NAME=wine-gecko

MAINFILES="$NAME[-_][0-9]"

(build_project $WINEETER_PATH/../WINE@Etersoft $NAME "" $@)

NAME=wine-mono

MAINFILES="$NAME[-_][0-9]"

(build_project $WINEETER_PATH/../WINE@Etersoft $NAME "" $@)


NAME=winetricks

MAINFILES="$NAME[-_][0-9]"

(build_project $WINEETER_PATH/../WINE@Etersoft $NAME "" $@)

