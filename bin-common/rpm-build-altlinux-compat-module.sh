#!/bin/sh
# 2005, 2006, 2007, 2008 (c) Etersoft http://etersoft.ru
# Author: Vitaly Lipatov <lav@etersoft.ru>
# GNU Public License version 3

#
# load common functions, compatible with local and installed script
. `dirname $0`/../share/eterbuild/korinf/common
kormod korinf

EXTRAFILES="rpm-build-intro rpm-build-compat rpm-macros-intro-conflicts"
build_project $WINEPUB_PATH rpm-build-altlinux-compat WINE $@
