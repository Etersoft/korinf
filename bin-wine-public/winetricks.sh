#!/bin/sh
# 2005, 2006, 2007, 2008 (c) Etersoft http://etersoft.ru
# Author: Vitaly Lipatov <lav@etersoft.ru>
# GNU Public License version 3
#

# load common functions, compatible with local and installed script
. `dirname $0`/../share/eterbuild/korinf/common
kormod korinf

NAME=winetricks

MAINFILES="$NAME[-_][0-9]"

#(build_project $WINEPUB_PATH/../Wine-public $NAME "" $@)
export KORINFMODULE=wine-7
(build_project $WINEPUB_PATH/7-unstable $NAME "WINE" $@)
exit
#export KORINFMODULE=wine5
#(build_project $WINEPUB_PATH/5.x $NAME "WINE" $@)
#export KORINFMODULE=wine6
#(build_project $WINEPUB_PATH/6.x $NAME "WINE" $@)
export KORINFMODULE=wine-7
(build_project $WINEPUB_PATH/7.x $NAME "WINE" $@)
export KORINFMODULE=wine
(build_project $WINEPUB_PATH/../Wine-staging $NAME "" $@)
export KORINFMODULE=wine
(build_project $WINEPUB_PATH/../Wine-vanilla $NAME "" $@)
