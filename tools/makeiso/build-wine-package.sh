#!/bin/sh
# 2005, 2006, 2007, 2008 (c) Etersoft http://etersoft.ru
# Author: Vitaly Lipatov <lav@etersoft.ru>
# GNU Public License

# Скрипт вызывается по ssh для сборки пакетов для ISO образа

cd `dirname $0`/..
. functions/helpers.sh

export SOURCEPATH=$WINEETER_PATH-disk/$WINENUMVERSION/$PRODUCT/sources
export TARGETPATH=$WINEETER_PATH-disk/$WINENUMVERSION/$PRODUCT/WINE

export NIGHTBUILD=1
build_rpm wine-etersoft-$PRODUCT
#-$WINENUMVERSION
