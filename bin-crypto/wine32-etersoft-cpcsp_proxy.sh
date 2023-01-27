#!/bin/sh
# 2005, 2006, 2007, 2008 (c) Etersoft http://etersoft.ru
# Author: Vitaly Lipatov <lav@etersoft.ru>
# GNU Public License version 3

NAME32=$(basename $0 .sh)
NAME=${NAME32/wine32/wine}

MAINFILES="$NAME32[-_][0-9]"

export KORINFMODULE=wine-7-unstable

$(dirname $0)/../bin/korinf $NAME "$@" /var/ftp/pvt/Etersoft/CRYPTO@Etersoft

