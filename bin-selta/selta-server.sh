#!/bin/sh
# 2026 (c) Etersoft http://etersoft.ru
# Author: Vitaly Lipatov <lav@etersoft.ru>
# GNU Public License version 3
#
# selta-server: selta-pg-setup and the SELTA schema for PostgreSQL for 1C
# (noarch, ALT only: it requires postgresql18-1C)

export SKIPBUILDLIST="FreeBSD OpenSolaris Windows"

NAME=$(basename $0 .sh)

export KORINFMODULE=selta

$(dirname $0)/../bin/korinf $NAME "$@" /var/ftp/pvt/Etersoft/SELTA@Etersoft
