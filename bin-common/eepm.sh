#!/bin/bash
# 2005, 2006, 2007, 2008, 2009 (c) Etersoft http://etersoft.ru
# Author: Vitaly Lipatov <lav@etersoft.ru>
# GNU Public License version 3

. `dirname $0`/../share/eterbuild/korinf/common
kormod korinf

MAINFILES="eepm[-_][0-9] eepm[-_][a-z]*[-_][0-9]"

# install only main package
[ "$2" = "-b" ] && MAINFILES="eepm[-_][0-9]"

build_project /var/ftp/pub/Korinf eepm "" $@
