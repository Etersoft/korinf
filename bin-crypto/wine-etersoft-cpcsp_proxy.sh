#!/bin/sh
# 2005, 2006, 2007, 2008 (c) Etersoft http://etersoft.ru
# Author: Vitaly Lipatov <lav@etersoft.ru>
# GNU Public License version 3

# load common functions, compatible with local and installed script
. `dirname $0`/../share/eterbuild/korinf/common
kormod korinf

export SKIPBUILDLIST="FreeBSD OpenSolaris Windows"

NAME=$(basename $0 .sh)

MAINFILES="wine-etersoft-cpcsp[-_]proxy[-_][0-9]"

#export KORINFMODULE=wine-9.0
. `dirname $0`/functions
set_ver "$@"

#$(dirname $0)/../bin/korinf $NAME "$@" /var/ftp/pvt/Etersoft/CRYPTO@Etersoft
(build_project /var/ftp/pvt/Etersoft/CRYPTO@Etersoft $NAME "" "$@")
