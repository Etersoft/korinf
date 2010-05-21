#!/bin/sh
# 2005, 2006, 2007, 2008 (c) Etersoft http://etersoft.ru
# Author: Vitaly Lipatov <lav@etersoft.ru>
# GNU Public License version 3

#
# load common functions, compatible with local and installed script
. `dirname $0`/../share/eterbuild/korinf/common
kormod korinf

major=8.4
pname=postgresql
pnamever=${pname}-${major}eter
POSTGRESDIR=/var/ftp/pub/Etersoft/Postgres@Etersoft/

# Проблема с тем, что пакет с библиотеками не -libs, а не libpq5.2
export MAINFILES="${pnamever}[-_][0-9] ${pnamever}-contrib[-_][0-9] ${pnamever}-server[-_][0-9] libpq5.2-${major}eter"
export EXTRAFILES="${pnamever}-devel[-_][0-9] ${pnamever}-docs[-_][0-9] ${pnamever}-plperl[-_][0-9] ${pnamever}-plpython[-_][0-9] ${pnamever}-test[-_][0-9]"

build_project $POSTGRESDIR ${pnamever} "" $@
