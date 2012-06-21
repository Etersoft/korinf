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

PRPATH=/var/ftp/pub/Etersoft/WINE@Etersoft/2.0-testing/WINE/ALTLinux/p6
assert_present_package $PRPATH wine-etersoft && echo "OK with 10.04"

#assert_present_package $PRPATH/10.10 etercifs && echo "OK with 10.10"
