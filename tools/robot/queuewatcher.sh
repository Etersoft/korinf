#!/bin/sh

# Запускать на builder
# Запускать с помощью monit
# Следит за файлами и отправляет на пересборку

PIDFILE=/var/run/eterbuild/queuewatcher.pid
SSHMOUNTOPT="sshfs_sync,no_readahead,cache=no,compression=yes,uid=$UID,gid=500"
SSHMOUNTBASE="sales:/var/www/site/downloads"

if [ "$1" = "stop" ] ; then
	kill `cat $PIDFILE`
	#killall -9 queuewatcher.sh
	killall -9 `pidof /bin/sh /home/builder/Projects/eterbuild/robot/queuewatcher.sh`
	exit
fi

fatal()
{
	echo $@
	exit 1
}

echo $$ >$PIDFILE

cd `dirname $0`/..

. functions/helpers.sh
ALOGDIR=$ALOGDIR-arobot

mkdir -p $ALOGDIR
touch $ALOGDIR/autobuild.batch.log || fatal "Can't append to log"

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
			xargs --no-run-if-empty -P1 -n1 robot/arobot.sh --real 2>&1 >> $ALOGDIR/autobuild.task.log
	fi
else
	while true ; do
		if ! mount -l | grep $TASKDIR >/dev/null ; then
		    sshfs $SSHMOUNTBASE $TASKDIR -o $SSHMOUNTOPT
		fi
		if [ "$1" = "debug" ] ; then
			ls -l robot/arobot.sh
			find $TASKDIR -maxdepth 1 -name "*.task" | head -n1
		else


			#(
			#flock 200
			TASKTORUN=`find $TASKDIR -maxdepth 1 -name "*.task" | head -n1`
			if [ -e "$TASKTORUN" ] ; then
				robot/arobot.sh --real $TASKTORUN 2>&1 >> $ALOGDIR/autobuild.task.log
			fi
			#find $TASKDIR -maxdepth 1 -name "*.task" | head -n1 | \
			#	xargs --no-run-if-empty -P1 -n1 robot/arobot.sh --real 2>&1 >> $ALOGDIR/autobuild.task.log
			#) 200> /tmp/queuewatcher.lock
		fi
		sleep 10
	done

fi
echo >$PIDFILE
