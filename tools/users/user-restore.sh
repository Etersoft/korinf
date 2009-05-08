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

set_rebuildlist
CMDRE=$(get_distro_list $REBUILDLIST)
[ -z "$CMDRE" ] && fatal "build list is empty"


for i in $CMDRE ; do
	TESTDIR=/net/os/stable/$i
	echo Chrooting to $i ...
#        $SUDO chroot /net/os/stable/$i restore_users
	cp -f ./remote-scripts/remote-restore-user.sh $TESTDIR/tmp
#test
	$SUDO chroot $TESTDIR sh -x /tmp/remote-restore-user.sh
#	echo "command $UCMD"
#	echo "new user $CHUSER"
#	echo "new group $CHGROUP"
#	echo "old user $OLDUSER"
#	echo "system $i"
#end of test
done

