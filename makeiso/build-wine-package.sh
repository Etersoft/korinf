#!/bin/sh
# 2005, 2006, 2007, 2008 (c) Etersoft http://etersoft.ru
# Author: Vitaly Lipatov <lav@etersoft.ru>
# GNU Public License

# Скрипт вызывается по ssh для сборки пакетов для ISO образа

# load common functions, compatible with local and installed script

cd `dirname $0`/..
. `dirname $0`/../share/eterbuild/korinf/common

kormod korinf

#export SOURCEPATH=$WINEETER_PATH-disk/$WINENUMVERSION/$PRODUCT/sources
#export TARGETPATH=$WINEETER_PATH-disk/$WINENUMVERSION/$PRODUCT/WINE
CPRODUCT=$1
shift

export NIGHTBUILD=1
build_project $WINEETER_PATH-disk wine-etersoft-$CPRODUCT "" $@
