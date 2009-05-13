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

if [ "$1" = "mount" ] ; then
	sshfs $SSHMOUNTBASE $TASKDIR -o $SSHMOUNTOPT
	exit
fi

#ALOGDIR=$ALOGDIR-arobot

#mkdir -p $ALOGDIR
#touch $ALOGDIR/autobuild.batch.log || fatal "Can't append to log"

if ! mount -l | grep $TASKDIR >/dev/null ; then
    test -r $TASKDIR/SKIPMOUNT || sshfs $SSHMOUNTBASE $TASKDIR -o $SSHMOUNTOPT || fatal "Can't mount"
fi

# Ждём появления файла и запускаем с ним сборку.
echo "Observe in $TASKDIR"

if false ; then

	if [ "$1" = "debug" ] ; then
		inotifywait -q -m -e close_write --format "%w%f" $TASKDIR
		#inotifywait -q -m --format "%w%f" $TASKDIR
		# | grep "\.task\$"
	else
		inotifywait -q -m -e close_write --format "%w%f" $TASKDIR | grep "\.task\$" |
			xargs --no-run-if-empty -P1 -n1 $AROBOT/arobot.sh --real 2>&1 #>> $ALOGDIR/autobuild.task.log
	fi
else
	while true ; do
		if ! mount -l | grep $TASKDIR >/dev/null ; then
		    sshfs $SSHMOUNTBASE $TASKDIR -o $SSHMOUNTOPT
		fi
		if [ -f "$TASKDIR/STOP" ] ; then
			echo "Stop build due STOP file"
			sleep 60
			continue
		fi
		if [ "$1" = "debug" ] ; then
			ls -l $AROBOT/arobot.sh
			find $TASKDIR -maxdepth 1 -name "*.task" | head -n1
		else


			#(
			#flock 200
			TASKTORUN=`find $TASKDIR -maxdepth 1 -name "*.task" | head -n1`
			if [ -e "$TASKTORUN" ] ; then
				$AROBOT/arobot.sh --real $TASKTORUN 2>&1 #>> $ALOGDIR/autobuild.task.log
			fi
			#find $TASKDIR -maxdepth 1 -name "*.task" | head -n1 | \
			#	xargs --no-run-if-empty -P1 -n1 robot/arobot.sh --real 2>&1 >> $ALOGDIR/autobuild.task.log
			#) 200> /tmp/queuewatcher.lock
		fi
		sleep 10
	done

fi
echo >$PIDFILE
