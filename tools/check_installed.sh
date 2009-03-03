#!/bin/sh
# 2006 (c) Etersoft www.etersoft.ru
# Public domain

# load common functions, compatible with local and installed script
. `dirname $0`/../share/eterbuild/korinf/common

TESTDIR=/tmp/autobuild/testlog
mkdir -p $TESTDIR

for i in $(get_distro_list $KORINFETC/lists/rebuild.list.all) ; do
	if set_target_type $i ; then
		continue
	fi
	echo Mount $i ...
	$SUDO mount $LOCALLINUXFARM/$i $TESTDIR --bind || exit 1
	#echo Mount local home...
	$SUDO mount /srv/builder $TESTDIR/home --bind -o soft || exit 1
	#echo Chrooting...
	#$SUDO chroot $TESTDIR su - $INTUSER -c "rpm -qa | grep wine | sed -e 's|^|    |g'"
	$SUDO chroot $TESTDIR su - -c "grep authorized_key /etc/ssh/sshd_config"
	$SUDO umount $TESTDIR/home #&& echo "Unmount home"
	$SUDO umount $TESTDIR #&& echo "Unmount $1"
done

