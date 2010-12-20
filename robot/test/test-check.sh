#!/bin/sh

cd ..
# load common functions, compatible with local and installed script
. `dirname $0`/../share/eterbuild/korinf/common

kormod check_built

AROBOTDIR=$(pwd)

. $AROBOTDIR/funcs/common
. $AROBOTDIR/funcs/build
. $AROBOTDIR/funcs/task
. $AROBOTDIR/funcs/etersoft

PRPATH=/var/ftp/pub/Etersoft/CIFS@Etersoft/stable/Ubuntu
check_package $PRPATH/10.04 etercifs && echo "OK with 10.04"

check_package $PRPATH/10.10 etercifs && echo "OK with 10.10"
