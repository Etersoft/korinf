#!/bin/sh
# 2005, 2006, 2007, 2008, 2009 (c) Etersoft http://etersoft.ru
# Author: Vitaly Lipatov <lav@etersoft.ru>
# GNU Public License version 3

if [ -n "$1" ] ; then
        LIST=$1
        shift
else
        LIST=all
fi

../bin/korinf $LIST etersoft-build-utils /var/ftp/pub/Etersoft/Sisyphus $@

