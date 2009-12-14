#!/bin/sh
# 2005, 2006, 2007, 2008, 2009 (c) Etersoft http://etersoft.ru
# Author: Vitaly Lipatov <lav@etersoft.ru>
# GNU Public License version 3

#
# load common functions, compatible with local and installed script
. `dirname $0`/../share/eterbuild/korinf/common
kormod korinf


build_extrapkg()
{
	EXTRAFILES="$1"
	shift
	build_project $WINEPUB_PATH "$EXTRAFILES" WINE $PROJVER $@
}

# install packages after build
BOOTSTRAP=1

build_extrapkg rpm-build-altlinux-compat $@
