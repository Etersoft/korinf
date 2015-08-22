#!/bin/sh
# 2005, 2006, 2007, 2008 (c) Etersoft http://etersoft.ru
# Author: Vitaly Lipatov <lav@etersoft.ru>
# GNU Public License version 3

export SKIPBUILDLIST="FreeBSD OpenSolaris Windows"

$(dirname $0)/../bin/korinf $1 haspd /var/ftp/pub/Etersoft/HASP $2 $3
