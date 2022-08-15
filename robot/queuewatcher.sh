#!/bin/sh
##
#  Korinf project
#
#  
#
#  Copyright (c) Etersoft <http://etersoft.ru> 2005, 2006, 2007, 2009
#  Copyright (c) Vitaly Lipatov <lav@etersoft.ru> 2009
#
#  This program is free software: you can redistribute it and/or modify
#  it under the terms of the GNU Affero General Public License as published by
#  the Free Software Foundation, either version 3 of the License, or
#  (at your option) any later version.

#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU Affero General Public License for more details.

#  You should have received a copy of the GNU Affero General Public License
#  along with this program.  If not, see <http://www.gnu.org/licenses/>.
##

# Запускать на builder
# Запускать с помощью monit
# Следит за файлами и отправляет на пересборку

PIDFILE=/var/run/eterbuild/queuewatcher.pid
SSHMOUNTOPT="reconnect,sshfs_sync,no_readahead,cache=yes,compression=yes,uid=$UID,gid=500"
SSHMOUNTBASE="sales:/var/www/site/downloads"

if [ "$1" = "stop" ] ; then
	kill `cat $PIDFILE`
	kill -9 `pidof /bin/sh /home/builder/Projects/korinf/robot/queuewatcher.sh | grep -v "$$"`
	exit
fi


fatal()
{
	echo $@
	exit 1
}

echo $$ >$PIDFILE || exit

AROBOT=`dirname $0`
# load common functions, compatible with local and installed script
. $AROBOT/../share/eterbuild/korinf/common
kormod korinf

. $AROBOT/config

mount_taskdir()
{
	fusermount -u $TASKDIR
	# TODO: add some check?
	fusermount -u -z $TASKDIR
	sshfs $SSHMOUNTBASE $TASKDIR -o $SSHMOUNTOPT
}

check_hangup()
{
	local FLAG=$(mktemp -u)
	rm -f $FLAG
	# try to detect hangup when accessing to $TASKDIR
	( stat $TASKDIR >/dev/null ; touch $FLAG) &
	sleep 5
	if [ ! -f $FLAG ] ; then
		killall -9 sshfs
	fi
	rm -f $FLAG
}

if [ "$1" = "now" ] ; then
	FLAGNOW=1
	shift
fi

if [ "$1" = "mount" ] ; then
	mount_taskdir
	exit
fi

while true ; do
	check_hangup
	if [ ! -r $TASKDIR/SALESDIR ] ; then
		sleep 3
		mount_taskdir
		echo "Paused due failed sshfs $SSHMOUNTBASE $TASKDIR -o $SSHMOUNTOPT"
		sleep 60
		continue
	fi
        # Note: do not check NFS root due NFS stale handle? (readlink explore every part of the path (/var, /var/ftp, /var/ftp/pub)
	# FIXME: local hack
	if [ ! -r /var/ftp/pub ] ; then
		echo "Paused due unreached /var/ftp/pub dir"
		sleep 60
		continue
	fi
	if [ ! -r /var/ftp/pvt ] ; then
		echo "Paused due unreached /var/ftp/pvt dir"
		sleep 60
		continue
	fi
	timeout 30m $AROBOT/hands/worker.sh $TASKDIR 2>&1
	test -n "$FLAGNOW" && break
	sleep 30
done

echo >$PIDFILE
