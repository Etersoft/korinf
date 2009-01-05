#/!bin/sh

# Запускать на server

PIDFILE=/var/run/eterbuild/watchbuilder.pid

cd `dirname $0`/..
. functions/config.in || fatal "Can't locate config.in"

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
	# load all vars (DIST, MAILTO, PRODUCT, ETERREGNUM, FULLNAME)
	printf "%9s %20s   %s\n %s %s" Reg.number Distro Product Mail "Full name"
	for TASK in `ls -1 $TASKDIR/*.$EXT` ; do
		. $TASK
		# Выводим название файла и дату создания
		stat -c "%n %y"
		echo
		printf "%s %20s   %s\n %s %s\n" "$ETERREGNUM" "$DIST" "$PRODUCT" "$MAILTO" "$FULLNAME"
	done
	#ls -l $TASKDIR/*.task
}

check_tasks()
{
#OLDCOUNT=`find $TASKDIR -maxdepth 1 -name "*.task" -cmin +10 | wc -l`
OLDCOUNT=`find $TASKDIR -maxdepth 1 -name "*.task" | wc -l`
OLDFCOUNT=`find $TASKDIR -maxdepth 1 -name "*.task.failed" | wc -l`
echo "Old tasks: $OLDCOUNT"

# Много застрявших заданий или поломанных сборок
if [ $OLDCOUNT -ge 10 ] ||  [ $OLDFCOUNT -ge 7 ] ; then
	echo Send mail...
	mutt -s "Build system failed" sales@etersoft.ru <<EOF
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
	mutt -s "Build system failed" lav@etersoft.ru boris@etersoft.ru <<EOF
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
	if check_tasks ; then
		SLEEP=120
	else
		SLEEP=$(($SLEEP*2))
	fi
	sleep $SLEEP
done

echo >$PIDFILE
