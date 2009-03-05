#!/bin/sh

AROBOTDIR=$(pwd)/..

. $AROBOTDIR/funcs/common
. $AROBOTDIR/funcs/task
. $AROBOTDIR/funcs/etersoft

cp tasks/test-wine-etersoft.task ./try.task

load_task ./try.task

PROJECTNAME="WINE@Etersoft"
VERNAME=$PROJECTNAME/$WINENUMVERSION
PUBLOCAL="/var/ftp/pub/Etersoft/$VERNAME"
PVTLOCAL="/var/ftp/pvt/Etersoft/$VERNAME/WINE-$(get_product_type "$PRODUCT")"

echo "PUBLOCAL: $PUBLOCAL"
echo "PVTLOCAL: $PVTLOCAL"

PRIVFILES=`find -L $PVTLOCAL/$DIST -maxdepth 1 -type f`
PUBLFILES=`find -L $PUBLOCAL/WINE/$DIST -maxdepth 1 -type f ; find -L $PUBLOCAL/fonts/$DIST -maxdepth 1 -type f`

echo "Files:"
for i in $PRIVFILES $PUBLFILES ; do
	echo $i
done
