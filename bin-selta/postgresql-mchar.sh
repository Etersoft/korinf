#!/bin/sh
# 2026 (c) Etersoft http://etersoft.ru
# Author: Vitaly Lipatov <lav@etersoft.ru>
# GNU Public License version 3
#
# postgresql-mchar: mchar of PostgreSQL for 1C for the PostgreSQL of the
# distribution (not ALT: PostgreSQL for 1C there has its own mchar)

export SKIPBUILDLIST="FreeBSD OpenSolaris Windows ALTLinux XimperLinux"

NAME=$(basename $0 .sh)

export KORINFMODULE=selta

$(dirname $0)/../bin/korinf $NAME "$@" /var/ftp/pvt/Etersoft/SELTA@Etersoft
