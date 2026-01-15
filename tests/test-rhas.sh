#!/bin/sh
# 2006 (c) Etersoft www.etersoft.ru
# Public domain

# load common functions, compatible with local and installed script
. `dirname $0`/../share/eterbuild/korinf/common

check()
{
    if rhas "$PROJECTVERSION" "^[789]" && rhas "$DIST" "^x86_64" && ! rhas "$PROJECTVERSION" "wow64" ; then
        echo "$DIST $PROJECTVERSION - 32 bit subpackage"
    else
	echo "$DIST $PROJECTVERSION - only main package wine-etersoft"
    fi
}

DIST=x86_64/AlterOS/7
PROJECTVERSION=9-unstable
check


DIST=x86_64/AlterOS/7
PROJECTVERSION=9-wow64-unstable
check

DIST=AlterOS/7
PROJECTVERSION=9-unstable
check

