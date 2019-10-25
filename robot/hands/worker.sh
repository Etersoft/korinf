#!/bin/sh
##
#  Korinf project
#
#  Build tasks from dir
#
#  Copyright (c) Etersoft <http://etersoft.ru> 2005, 2006, 2007, 2009, 2010
#  Copyright (c) Vitaly Lipatov <lav@etersoft.ru> 2009, 2010
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



fatal()
{
	echo "$*" >&2
	exit 1
}


AROBOT=`dirname $0`/..
# load common functions, compatible with local and installed script
TOPDIR=../../
. $AROBOT/../share/eterbuild/korinf/common
kormod korinf

list_tasks()
{
	find $TASKDIR -maxdepth 1 -name "*.$1" | sort
}

TASKDIR="$1"
[ -d "$TASKDIR" ] || fatal "missed param: $TASKDIR"
shift
echo -n "Observe in $TASKDIR at "
date

if [ ! -r $TASKDIR/SALESDIR ] ; then
	sleep 3
	fatal "Can't detect $TASKDIR/SALESDIR"
fi

if [ -f "$TASKDIR/STOP" ] ; then
	echo "Stop build due $TASKDIR/STOP file"
	sleep 60
	exit
fi

if [ "$1" = "debug" ] ; then
	TASKCOMMAND="--debug"
else
	TASKCOMMAND="--real"
fi

# Remove stalled task.run
for TASKTORUN in $(list_tasks task.run) ; do
	TASKPID=$(cat $TASKTORUN)
	[ -r "/proc/$TASKPID" ] && continue
	echo "Pid $TASKPID from $TASKTORUN is unexisted, set interrupted"
	TASKFILE=${TASKTORUN/.run/}
	mv -f $TASKFILE $TASKFILE.interrupted
	rm -f $TASKTORUN
done

#COPYTASKDIR="${TASKDIR}/copytsks"

for TASKTORUN in $(list_tasks task) ; do
	[ -e "$TASKTORUN" ] || continue
	
	# drop strange copying
	#NAMETASKTOCP=$(basename ${TASKTORUN})
	#FULLNAMECOPYTASK="${COPYTASKDIR}/${NAMETASKTOCP}.tsk"
	#
	#if [ ! -e "${FULLNAMECOPYTASK}" ]
	#then
	#    mkdir -p "${COPYTASKDIR}"
	#    cp "${TASKTORUN}" "${FULLNAMECOPYTASK}"
	#fi
	
	flock $TASKTORUN test -e "$TASKTORUN.run" && continue
	echo $$ >$TASKTORUN.run
	$AROBOT/hands/buildtask.sh $TASKCOMMAND $TASKTORUN 2>&1
	rm -f "$TASKTORUN.run"
	
done
