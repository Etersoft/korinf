#!/bin/sh
# 2005, 2006, 2007, 2008 (c) Etersoft http://etersoft.ru
# Author: Vitaly Lipatov <lav@etersoft.ru>
# GNU Public License version 3
#

# load common functions, compatible with local and installed script
. `dirname $0`/../share/eterbuild/korinf/common
kormod korinf

NAME=wine-gecko

MAINFILES="$NAME[-_][0-9]"

#export KORINFMODULE=wine-5-nalog3
#(build_project $WINEETER_PATH/5-nalog3 $NAME "WINE" $@)
#exit

export KORINFMODULE=wine-7
#(build_project $WINEPUB_PATH/7.x $NAME "WINE" $@)

(build_project $WINEPUB_PATH/7-unstable $NAME "WINE" $@)
exit

#(build_project $WINEPUB_PATH/../Wine-public $NAME "" $@)
export KORINFMODULE=wine-5
(build_project $WINEPUB_PATH/5.x $NAME "WINE" $@)
export KORINFMODULE=wine-6
(build_project $WINEPUB_PATH/6.x $NAME "WINE" $@)
export KORINFMODULE=wine-7
(build_project $WINEPUB_PATH/7.x $NAME "WINE" $@)

export KORINFMODULE=wine
(build_project $WINEPUB_PATH/../Wine-staging $NAME "" $@)
export KORINFMODULE=wine
(build_project $WINEPUB_PATH/../Wine-vanilla $NAME "" $@)
