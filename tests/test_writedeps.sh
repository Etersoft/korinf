#!/bin/bash
# 2006 (c) Etersoft www.etersoft.ru
# Public domain

# load common functions, compatible with local and installed script
. `dirname $0`/../share/eterbuild/korinf/common

kormod writedeps

#write_altdeps_by_list /var/ftp/pvt/Etersoft/Sisyphus/ALTLinux/Sisyphus "libpjsip-debuginfo*.rpm libpjsip*.rpm libpjsip-devel*.rpm "
DESTDIR=/var/ftp/pvt/Etersoft/Sisyphus/ALTLinux/Sisyphus
EXPMAINFILES="libpjsip-debuginfo*.rpm libpjsip*.rpm libpjsip-devel*.rpm "
write_altdeps
