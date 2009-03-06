#!/bin/sh

cd ..
# load common functions, compatible with local and installed script
. `dirname $0`/../share/eterbuild/korinf/common

AROBOTDIR=$(pwd)

. $AROBOTDIR/funcs/common
. $AROBOTDIR/funcs/build
. $AROBOTDIR/funcs/task
. $AROBOTDIR/funcs/etersoft

cp test/tasks/test-wine-etersoft.task ./try.task

load_task ./try.task

PROJECTNAME="WINE@Etersoft"
VERNAME=$PROJECTNAME/$WINENUMVERSION
PUBLOCAL="/var/ftp/pub/Etersoft/$VERNAME/WINE"
PVTLOCAL="/var/ftp/pvt/Etersoft/$VERNAME/WINE-$(get_product_type "$PRODUCT")"

check_built_package $PUBLOCAL/$DIST ../../../sources haspd
