#!/bin/sh
# 2005, 2006, 2007, 2008 (c) Etersoft http://etersoft.ru
# Author: Vitaly Lipatov <lav@etersoft.ru>
# GNU Public License version 3
#

# load common functions, compatible with local and installed script
. `dirname $0`/../share/eterbuild/korinf/common
kormod korinf

NAME=wine-mono

MAINFILES="$NAME[-_][0-9]"

. `dirname $0`/functions

set_ver "$@"

(build_project $WINEPUB_PATH $NAME "WINE" "$@")
