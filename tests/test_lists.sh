#!/bin/bash
# 2006 (c) Etersoft www.etersoft.ru
# Public domain

# load common functions, compatible with local and installed script
. `dirname $0`/../share/eterbuild/korinf/common

#kormod writedeps
KORINFETC=../etc

check_multiarch_wine_system()
{
	grep -q "^$1 *$" $KORINFETC/multiarch-wine
}

check_multiarch_wine_system AstraLinux/orel && echo OK
