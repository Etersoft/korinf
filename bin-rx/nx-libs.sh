#!/bin/sh
# 2005, 2006, 2007, 2008 (c) Etersoft http://etersoft.ru
# Author: Vitaly Lipatov <lav@etersoft.ru>
# GNU Public License version 3

#
# load common functions, compatible with local and installed script
. `dirname $0`/../share/eterbuild/korinf/common
kormod korinf

export KORINFMODULE=rx

SKIPBUILDLIST="OpenSolaris Windows"

# В unstable версии у нас теперь на одну цифру больше
#
# Нормальное регулярное выражение выглядит так
#  ... [-_] [0-9] (.[0-9]){4} [-_]
# name -    3     .5.99.27.3  -
#
#  ... [-_] [0-9]  (.[0-9]){5} [-_]
# name -    3     .5.99.27.3.1 -
#
# Но регулярки в shell не умеют мультиплицировать с помощью {n}
# Поэтому приходится копировать вручную
# Возможно есть более элегантный вариант, который стоит найти
# В логах сборки данные паттерны выгдлядят ужасно

# Unstable 5 цифр
UNSTABLE="nx-libs[-_][0-9].[0-9].[0-9][0-9].[0-9][0-9].[0-9].[0-9][-_]
	  nxproxy[-_][0-9].[0-9].[0-9][0-9].[0-9][0-9].[0-9].[0-9][-_]
	  nxagent[-_][0-9].[0-9].[0-9][0-9].[0-9][0-9].[0-9].[0-9][-_]"
UNSTABLEEXTRA="nx-libs-devel[-_][0-9].[0-9].[0-9][0-9].[0-9][0-9].[0-9].[0-9][-_]"

# Все остальные 4-е цифры
# Simplified pattern to support versions like 3.5.99.27
MAINFILES="nx-libs[-_][0-9] nxproxy[-_][0-9] nxagent[-_][0-9]"
EXTRAFILES="nx-libs-devel[-_][0-9]"

# Оригинальный вариант
#MAINFILES="nx-libs[-_][0-9] nxproxy[-_][0-9] nxagent[-_][0-9]"
#EXTRAFILES="nx-libs-devel[-_][0-9]"

# Check for unstable
last_arg="$(echo "$@" | cut -d" " -f$#)"
[ "$last_arg" = "unstable" ] && { MAINFILES=$UNSTABLE; EXTRAFILES=$UNSTABLEEXTRA;}
#echo "MAINFILES: $MAINFILES"

build_project /var/ftp/pvt/Etersoft/RX@Etersoft nx-libs "" $@
