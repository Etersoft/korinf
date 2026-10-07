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
#MAINFILES="nx-libs[-_][0-9].[0-9].[0-9][0-9].[0-9][0-9].[0-9][-_]
#	   nxproxy[-_][0-9].[0-9].[0-9][0-9].[0-9][0-9].[0-9][-_]
#	   nxagent[-_][0-9].[0-9].[0-9][0-9].[0-9][0-9].[0-9][-_]"
#EXTRAFILES="nx-libs-devel[-_][0-9].[0-9].[0-9][0-9].[0-9][0-9].[0-9][-_]"
MAINFILES="nx-libs[-_][0-9] nxproxy[-_][0-9] nxagent[-_][0-9]"
EXTRAFILES="nx-libs-devel[-_][0-9]"

# Оригинальный вариант
#MAINFILES="nx-libs[-_][0-9] nxproxy[-_][0-9] nxagent[-_][0-9]"
#EXTRAFILES="nx-libs-devel[-_][0-9]"

# Check for unstable
# the product version: the second argument that is not an option
# (System/Version Version [-b|-f|-c ...]), not the last one
last_arg="$(for a in "$@" ; do case "$a" in -*) ;; *) echo "$a" ;; esac ; done | sed -n 2p)"
#[ "$last_arg" = "unstable" ] && { MAINFILES=$UNSTABLE; EXTRAFILES=$UNSTABLEEXTRA;}
#echo "MAINFILES: $MAINFILES"

# ---------------------------------------------------
# А может awk?
# 1 Сортируем все src.rpm пакеты по убыванию и берём первую строку
# 2 awk: Получаем имя пакета методом деления строки по имени пакета
# 3 awk: У результата убираем "alt[0-9]+src.rpm" в конце файла
NXVER=$(ls /var/ftp/pvt/Etersoft/RX@Etersoft/$last_arg/sources/nx-libs* -1 -r | head -n 1 | awk -F"nx-libs-" '{gsub(/alt[0-9]+.*src.rpm/, ""); print $2}') # == "3.5.99.27.3-"
MAINFILES="nx-libs[-_]$NXVER nxproxy[-_]$NXVER nxagent[-_]$NXVER"
EXTRAFILES="nx-libs-devel[-_]$NXVER"
echo "MAINFILES: $MAINFILES"
echo "EXTRAFILES: $EXTRAFILES"

build_project /var/ftp/pvt/Etersoft/RX@Etersoft nx-libs "" $@
