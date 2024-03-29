#!/bin/sh
# 2005, 2006, 2007, 2008 (c) Etersoft http://etersoft.ru
# Author: Vitaly Lipatov <lav@etersoft.ru>
# GNU Public License version 3
#

# load common functions, compatible with local and installed script
. `dirname $0`/../share/eterbuild/korinf/common
kormod korinf

. `dirname $0`/functions
set_ver "$@"

NAME=wine-grdwine
NAME32=wine32-grdwine

MAINFILES="$NAME32[-_][0-9]"

(build_project $WINEPUB_PATH $NAME "WINE" "$@")
