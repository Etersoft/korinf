#!/bin/sh
# 2005, 2006, 2007, 2008 (c) Etersoft http://etersoft.ru
# Author: Vitaly Lipatov <lav@etersoft.ru>
# GNU Public License version 3

export SKIPBUILDLIST="FreeBSD OpenSolaris Windows"

case "$1" in
    -*)
        LIST=dkms
        ;;
    *)
        LIST="$1"
        shift
esac

$(dirname $0)/../bin/korinf dkms-aksparlnx $LIST /var/ftp/pub/Etersoft/HASP "$@"
