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
SSHMOUNTOPT="sshfs_sync,no_readahead,cache=no,compression=yes,uid=$UID,gid=500"
SSHMOUNTBASE="sales:/var/www/site/downloads"

if [ "$1" = "stop" ] ; then
	kill `cat $PIDFILE`
	#killall -9 queuewatcher.sh
	killall -9 `pidof /bin/sh /home/builder/Projects/korinf/robot/queuewatcher.sh`
	exit
fi


fatal()
{
	echo $@
	exit 1
}

echo $$ >$PIDFILE

AROBOT=`dirname $0`
# load common functions, compatible with local and installed script
. $AROBOT/../share/eterbuild/korinf/common
kormod korinf

. $AROBOT/config

mount_taskdir()
{
	sshfs $SSHMOUNTBASE $TASKDIR -o $SSHMOUNTOPT
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
	if [ ! -r $TASKDIR/SALESDIR ] ; then
		sleep 3
		mount_taskdir
		echo "Paused due failed sshfs $SSHMOUNTBASE $TASKDIR -o $SSHMOUNTOPT"
		sleep 60
		continue
	fi
	timeout 30m $AROBOT/hands/worker.sh $TASKDIR 2>&1
	test -n "$FLAGNOW" && break
	sleep 30
done

echo >$PIDFILE
