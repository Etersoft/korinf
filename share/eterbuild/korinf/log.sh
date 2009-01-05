#!/bin/bash
# 2005, 2006, 2007, 2008 (c) Etersoft http://etersoft.ru
# Author: Vitaly Lipatov <lav@etersoft.ru>
# GNU Public License version 3
#

export COLUMNS=80
. $KORINFDIR/korinf/outformat.sh

success()
{
	MOVE_TO_COL
	echo -n '[ '
	SETCOLOR_SUCCESS
	echo -n 'DONE'
	SETCOLOR_NORMAL
	echo -n ' ]'
}

failure()
{
	MOVE_TO_COL
	echo -n '['
	SETCOLOR_FAILURE
	echo -n 'FAILED'
	SETCOLOR_NORMAL
	echo -n ']'
}

init_log()
{
	LLOGDIR=$ALOGDIR/${dist}
	mkdir -p $LLOGDIR || fatal "Can't create $LLOGDIR"
	LOGFILE=$LLOGDIR/$BUILDNAME.log
	>$LOGFILE || fatal "Can't create log"
}

copying_log()
{
	local DESTLOGFILE
	#if [ "$BUILDNAME" != "wine" ] && [ "$REPL" != "yes" ] ; then
	#	echo -e " SKIPPING "
	#	return 0
	#fi
	mkdir -p $DESTDIR/log/
	DESTLOGFILE=$DESTDIR/log/`basename $LOGFILE`
	cp $LOGFILE $DESTLOGFILE
	rm -f $DESTLOGFILE.bz2
	bzip $DESTLOGFILE
}

print_spaces_instead_string()
{
	local LEN STR SPACES
	STR="$1"
	LEN=${#STR}
	SPACES="                                                  "
	echo "$SPACES" | cut -c 1-$LEN
}

PREVSYSTEMLOGIT=
logit()
{
	local RET STRMSG SYSNOW
	if [ "$PREVSYSTEMLOGIT" = "$dist" ] ; then
		SYSNOW=`print_spaces_instead_string "$dist"`
	else
		echo
		SYSNOW=$dist
	fi
	STRMSG="$SYSNOW * [`date '+%R'`] $1 ... "
	PREVSYSTEMLOGIT=$dist
	# print one line if scripted night build
	[ -z "$NIGHTBUILD" ] && echo -n "$STRMSG"
	shift
	TIMESTAMP=`date "+%s"`
	$* >>$LOGFILE 2>&1
	RET=$?
	let TIMESTAMP=`date "+%s"`-$TIMESTAMP
	[ -z "$NIGHTBUILD" ] && STRMSG=""
	#[ "$RET" = 0 ] && STRMSG="$STRMSG done" || STRMSG="$STRMSG FAILED"
	#[ $TIMESTAMP = "0" ] && echo "$STRMSG" || echo "$STRMSG ($TIMESTAMP сек)"
	echo -n "$STRMSG"
	[ $TIMESTAMP = "0" ] || echo -n "($TIMESTAMP сек) "
	[ "$RET" = 0 ] && success || failure
	echo
	return $RET
}

