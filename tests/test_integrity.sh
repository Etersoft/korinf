#!/bin/bash
# 2006 (c) Etersoft www.etersoft.ru
# Public domain

# load common functions, compatible with local and installed script
. `dirname $0`/../share/eterbuild/korinf/common

kormod check_integrity

check_files_integrity /var/ftp/pub/Etersoft/WINE@Etersoft/1.0.12/sources
check_files_integrity /var/ftp/pub/Etersoft/WINE@Etersoft/1.0.12/sources/tarball
check_files_integrity /var/ftp/pub/Etersoft/WINE@Etersoft/1.0.12/WINE/Debian/5.0
