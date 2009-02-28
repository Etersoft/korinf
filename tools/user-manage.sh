#!/bin/sh
# 2006 (c) Etersoft www.etersoft.ru
# Public domain

# load common functions, compatible with local and installed script
. ../share/eterbuild/korinf/common
kormod mount korinf

TESTDIR=/tmp/autobuild/testlog
mkdir -p $TESTDIR

UCMD=$1
CHUSER=$2

if [ -z $2] ; then
	CHGROUP=$2
else
	CHGROUP=$3
fi

for i in $(get_distro_list $KORINFETC/lists/all) ; do
	echo Mount $i ...
        $SUDO mount $LINUXHOST/$i $TESTDIR --bind || exit 1

	mkdir -p $TESTDIR/tmp
        cp -f  ./remote-$UCMD-user.sh $TESTDIR/tmp || { warning "Cannot copy script" ; return 1 ; }
	echo Chrooting and executing...
        $SUDO chroot $TESTDIR su - -c "sh -x /tmp/remote-$UCMD-user.sh \"$CHUSER\" \"$CHGROUP\""
#test
#	$SUDO chroot $TESTDIR su - -c "mkdir -p /tmp/add-user"
	$SUDO umount $TESTDIR && echo "Unmount $i"
done

rm -rf $TESTDIR