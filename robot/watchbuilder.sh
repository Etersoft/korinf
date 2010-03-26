#/!bin/sh
##
#  Korinf project
#
#  Watcher
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

# Запускать на server

PIDFILE=/var/run/eterbuild/watchbuilder.pid

# load common functions, compatible with local and installed script
. `dirname $0`/../share/eterbuild/korinf/common

kormod messages/jabber

. `dirname $0`/config

if [ "$1" = "stop" ] ; then
	kill `cat $PIDFILE`
	killall -9 $0
	exit
fi

echo $$ >$PIDFILE

export LANG=ru_RU.UTF-8
export LC_ALL=ru_RU.UTF-8

print_tasks()
{
	local TASK EXT
	EXT=$1
	printf "%9s %20s   %s\n %s %s" Reg.number Distro Component Mail "Full name"
	for TASK in `ls -1 $TASKDIR/*.$EXT` ; do
		. $TASK
		# Выводим название файла и дату создания
		stat -c "%n %y"
		echo
		printf "%s %20s   %s\n %s %s\n" "$ETERREGNUM" "$DIST" "$COMPONENTNAME" "$MAILTO" "$FULLNAME"
	done
	#ls -l $TASKDIR/*.task
}

check_host()
{
	local HOST=sales.etersoft.ru
	if ! ping -c1 $HOST && sleep 3 && ! ping -c1 $HOST ; then
		echo Send mail...
		mutt -s "Build system hangup" lav@etersoft.ru yurifil@etersoft.ru <<EOF
Build system possible is hangup due sales.etersoft.ru unreachable.

EOF
		send_by_jabber -s "Build system hangup" lav@im.etersoft.ru yurifil@im.etersoft.ru <<EOF
Build system possible is hangup due sales.etersoft.ru unreachable.
EOF
		return 1
	fi

	return 0
}


check_tasks()
{
# TODO: check for hangup due sshfs stranges
#OLDCOUNT=`find $TASKDIR -maxdepth 1 -name "*.task" -cmin +10 | wc -l`
OLDCOUNT=`find $TASKDIR -maxdepth 1 -name "*.task" | wc -l`
OLDFCOUNT=`find $TASKDIR -maxdepth 1 -name "*.task.failed" | wc -l`
echo "Old tasks: $OLDCOUNT"

# Много застрявших заданий или поломанных сборок
if [ $OLDCOUNT -ge 10 ] ||  [ $OLDFCOUNT -ge 7 ] ; then
	echo Send mail...
	mutt -s "Build system failed" lav@etersoft.ru yurifil@etersoft.ru <<EOF
Build system is supended with $OLDCOUNT tasks:
`print_tasks task`

There are $OLDFCOUNT failed tasks:
`print_tasks task.failed`

EOF

	send_by_jabber -s "Build system failed" lav@im.etersoft.ru yurifil@im.etersoft.ru <<EOF
Build system is supended with $OLDCOUNT tasks:
`print_tasks task`

There are $OLDFCOUNT failed tasks:
`print_tasks task.failed`

EOF
	return 1
fi

# Не смонтирован каталог
#if ! mount -l | grep $TASKDIR >/dev/null ; then
if [ ! -r "$TASKDIR/SALESDIR" ] ; then
	mutt -s "Build system failed" lav@etersoft.ru <<EOF
Build directory $TASKDIR is unmounted.
Check it immediately.

`ls -l $TASKDIR/*`
EOF
	return 1
fi

	return 0

}

SLEEP=120
while true; do
	if check_host && check_tasks ; then
		SLEEP=120
	else
		SLEEP=$(($SLEEP*2))
	fi
	sleep $SLEEP
done

echo >$PIDFILE
