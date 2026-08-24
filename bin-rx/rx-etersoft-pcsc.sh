#!/bin/sh
# 2005, 2006, 2007, 2008 (c) Etersoft http://etersoft.ru
# Author: Vitaly Lipatov <lav@etersoft.ru>
# GNU Public License version 3

#
# load common functions, compatible with local and installed script
. `dirname $0`/../share/eterbuild/korinf/common
kormod korinf

export KORINFMODULE=rx

MAINFILES="rx-etersoft-pcsc[-_][0-9] rxclient-pcsc[-_][0-9]"
# FIXME:
# На этапе копирования удаляется также пакет rx-etersoft-pcsc-driver
# Removing old 'rxclient-pcsc rx-etersoft-pcsc  ' by mask 'rxclient-pcsc*.rpm rx-etersoft-pcsc*.rpm  ' from /var/ftp/pvt/Etersoft/RX@Etersoft/1.10/x86_64/ALTLinux/Sisyphus...
#removed 'rx-etersoft-pcsc-1.10.0-alt1.x86_64.rpm'
#removed 'rx-etersoft-pcsc-driver-1.10.0-alt1.x86_64.rpm'

# Get product version from last arg
PRODUCT_VER="$(echo "$@" | cut -d" " -f$#)"

PCSCVER=$(ls /var/ftp/pvt/Etersoft/RX@Etersoft/$PRODUCT_VER/sources/rx-etersoft-pcsc-[0-9]* -1 -r | head -n 1 | awk -F"rx-etersoft-pcsc-" '{gsub(/alt[0-9]+.src.rpm/, ""); print $2}')
MAINFILES="rx-etersoft-pcsc[-_][$PCSCVER] rxclient-pcsc[-_][$PCSCVER]"
echo "MAINFILES: $MAINFILES"

build_project /var/ftp/pvt/Etersoft/RX@Etersoft rx-etersoft-pcsc "" $@
