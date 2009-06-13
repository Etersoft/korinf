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

cp test/tasks/test-wine-etersoft.task ./try.task

load_task ./try.task

PROJECTNAME="WINE@Etersoft"
VERNAME=$PROJECTNAME/$PROJECTVERSION
PUBLOCAL="/var/ftp/pub/Etersoft/$VERNAME/WINE"
PVTLOCAL="/var/ftp/pvt/Etersoft/$VERNAME/WINE-$(get_product_type "$COMPONENTNAME")"

SOURCEPATH=$PUBLOCAL/../sources
TARGETPATH=$PUBLOCAL
check_built_package  haspd
