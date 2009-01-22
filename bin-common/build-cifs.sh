#!/bin/sh
# 2005, 2006, 2007, 2008 (c) Etersoft http://etersoft.ru
# Author: Vitaly Lipatov <lav@etersoft.ru>
# GNU Public License version 3

#
# load common functions, compatible with local and installed script
. `dirname $0`/../share/eterbuild/korinf/common
kormod korinf

CIFSDIR=/var/ftp/pub/Etersoft/CIFS@Etersoft
CIFSVERSION=4.1.1

#build_project $CIFSDIR etercifs "" $CIFSVERSION $@
build_project $CIFSDIR dkms-etercifs "" $CIFSVERSION $@