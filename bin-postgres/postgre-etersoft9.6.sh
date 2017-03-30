#!/bin/sh
# 2005, 2006, 2007, 2008 (c) Etersoft http://etersoft.ru
# Author: Vitaly Lipatov <lav@etersoft.ru>
# GNU Public License version 3

#
# load common functions, compatible with local and installed script
. `dirname $0`/../share/eterbuild/korinf/common
kormod korinf

libpq=5.9
major=9.6

pname=postgre-etersoft
pnamever=${pname}${major}
POSTGRESDIR=/var/ftp/pub/Etersoft/Postgres@Etersoft/

# Проблема с тем, что пакет с библиотеками не -libs, а libpq5.2
export MAINFILES="${pnamever}-seltaaddon[-_][0-9] ${pnamever}[-_][0-9] ${pnamever}-contrib[-_][0-9] ${pnamever}-server[-_][0-9] libpq${libpq}-${major}eter"
#export EXTRAFILES="${pnamever}-devel[-_][0-9] ${pnamever}-docs[-_][0-9] ${pnamever}-plperl[-_][0-9] ${pnamever}-plpython[-_][0-9] ${pnamever}-test[-_][0-9]"
#export EXTRAFILES="${pnamever}-docs[-_][0-9] ${pnamever}-plperl[-_][0-9] ${pnamever}-plpython[-_][0-9]"
export EXTRAFILES="${pnamever}-plperl[-_][0-9] ${pnamever}-plpython[-_][0-9]"

build_project $POSTGRESDIR ${pnamever} "" $@
