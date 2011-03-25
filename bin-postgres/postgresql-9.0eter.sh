#!/bin/bash
# 2005, 2006, 2007, 2008 (c) Etersoft http://etersoft.ru
# Author: Vitaly Lipatov <lav@etersoft.ru>
# GNU Public License version 3

#
# load common functions, compatible with local and installed script
. `dirname $0`/../share/eterbuild/korinf/common
kormod korinf

major=9.0
pname=postgresql
pnamever=${pname}-${major}
POSTGRESDIR=/var/ftp/pub/Etersoft/Postgres@Etersoft/

# Проблема с тем, что пакет с библиотеками не -libs, а не libpq5.2
export MAINFILES="${pname}[-_]${major}eter ${pname}-contrib[-_]${major}eter ${pname}-server[-_]${major}eter libpq5.2-${major}eter"
export EXTRAFILES="${pname}-devel[-_]${major}eter ${pname}-docs[-_]${major}eter ${pname}-plperl[-_]${major}eter ${pname}-plpython[-_]${major}eter ${pname}-test[-_]${major}eter"

build_project $POSTGRESDIR ${pnamever}  ""  $@
exit
