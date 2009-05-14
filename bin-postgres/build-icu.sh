#!/bin/sh

#!/bin/sh
# 2005, 2006, 2007, 2008 (c) Etersoft http://etersoft.ru
# Author: Vitaly Lipatov <lav@etersoft.ru>
# GNU Public License version 3

#
# load common functions, compatible with local and installed script
. `dirname $0`/../share/eterbuild/korinf/common
kormod korinf

POSTGRESDIR=/var/ftp/pub/Etersoft/PostgreSQL/

export EXTRAFILES="libicu38[-_][0-9] libicu38-devel[-_][0-9] icu38-samples[-_][0-9] icu38-utils[-_][0-9]"

# install packages after build
export BOOTSTRAP=1

build_project $POSTGRESDIR icu38 "" $@
