#!/bin/sh
# 2006 (c) Etersoft www.etersoft.ru
# Public domain
#
#Usage:
#user_manage.sh {add, delete, change} NEWUSER NEWGROUP OLDUSER
#


# load common functions, compatible with local and installed script
. `dirname $0`/../share/eterbuild/korinf/common
kormod korinf

TESTDIR=/tmp/autobuild/testlog
mkdir -p $TESTDIR

UCMD=$1

CHUSER=$2
shift 2
if [ -z $1] ; then
	CHGROUP=$CHUSER
	shift
else
	CHGROUP=$1
	shift
fi
OLDUSER=$1
shift
if [ -z $1] ; then
	OLDGROUP=$OLDUSER
else
	OLDGROUP=$1
fi

set_rebuild_list
CMDRE=$(get_distro_list $REBUILDLIST)
[ -z "$CMDRE" ] && fatal "build list is empty"


for i in $CMDRE ; do
	echo Mount $i ...
        $SUDO mount $LINUXHOST/$i $TESTDIR --bind || exit 1

	mkdir -p $TESTDIR/tmp
        cp -f  ./remote-$UCMD-user.sh $TESTDIR/tmp || { warning "Cannot copy script" ; return 1 ; }
	echo Chrooting and executing...
        $SUDO chroot $TESTDIR su - -c "sh -x /tmp/remote-$UCMD-user.sh \"$CHUSER\" \"$CHGROUP\" \"$OLDUSER\" \"$OLDGROUP\""

#test
#	$SUDO chroot $TESTDIR su - -c "mkdir -p /tmp/add-user-$CHUSER"
#	echo "command $UCMD"
#	echo "new user $CHUSER"
#	echo "new group $CHGROUP"
#	echo "old user $OLDUSER"
#	echo "system $i"
#end of test
	rm -f $TESTDIR/tmp/remote-$UCMD-user.sh
	$SUDO umount $TESTDIR && echo "Unmount $i"
done

rm -rf $TESTDIR