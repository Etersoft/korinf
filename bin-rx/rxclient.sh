#!/bin/sh
# 2005, 2006, 2007, 2008 (c) Etersoft http://etersoft.ru
# Author: Vitaly Lipatov <lav@etersoft.ru>
# GNU Public License version 3

#
# load common functions, compatible with local and installed script
. `dirname $0`/../share/eterbuild/korinf/common
kormod korinf

export KORINFMODULE=rx

MAINFILES="rxclient[-_][0-9]"

# !!! В данном варианте не удаляются старые версии из DESTDIR(/var/ftp/pvt/) !!!
# -----------------------------------
# # FIXME: Use precise pattern to avoid removing rxclient-pcsc packages
#
# PACKAGE_PATTERN="rxclient-[0-9]*"
#
# # Get product version from last arg
# PRODUCT_VER="$(echo "$@" | cut -d" " -f$#)"
#
# # TODO: Можно ли сделать более читабельнее?
# RXCLIENTVER=$(ls /var/ftp/pvt/Etersoft/RX@Etersoft/$PRODUCT_VER/sources/$PACKAGE_PATTERN -1 -r | head -n 1 | awk -F"rxclient-" '{gsub(/alt[0-9]+.src.rpm/, ""); print $2}')
#
# MAINFILES="rxclient[-_]$RXCLIENTVER"
# -----------------------------------
echo "MAINFILES: $MAINFILES"

build_project /var/ftp/pvt/Etersoft/RX@Etersoft rxclient "" $@
