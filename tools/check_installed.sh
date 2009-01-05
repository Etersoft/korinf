#!/bin/sh
# 2006 (c) Etersoft www.etersoft.ru
# Public domain

. /etc/rpm/etersoft-build-functions

cd `dirname $0`/..

. functions/config.in || fatal "Can't locate config.in"
#. functions/helpers.sh


#export WORKDIR=/var/ftp/pvt/Etersoft
TESTDIR=/tmp/autobuild/testlog
mkdir -p $TESTDIR

for i in `cat lists/rebuild.list.all | grep -v "^#" | cut -f 1 -d " "` ; do
	if set_target_type $i ; then
		continue
	fi
	echo Mount $i ...
	$SUDO mount $LINUXHOST/$i $TESTDIR --bind || exit 1
	#echo Mount local home...
	$SUDO mount /srv/builder $TESTDIR/home --bind -o soft || exit 1
	#echo Chrooting...
	#$SUDO chroot $TESTDIR su - $INTUSER -c "rpm -qa | grep wine | sed -e 's|^|    |g'"
	$SUDO chroot $TESTDIR su - -c "grep authorized_key /etc/ssh/sshd_config"
	$SUDO umount $TESTDIR/home #&& echo "Unmount home"
	$SUDO umount $TESTDIR #&& echo "Unmount $1"
done

