#!/bin/sh
# скрипт на той стороне
# создание /srv/wine
# TODO: монтирование /proc и /dev/pts
#export LANG=C

cd `dirname $0`/..

. functions/config.in || fatal "Can't locate config.in"

#export WORKDIR=/home/builder/Projects/eterbuild
#. $WORKDIR/functions/config.in

SUDO="sudo"
if [ $UID = "0" ]; then
	SUDO=""
fi

if [ -z "$1" ] ; then
	echo "Login in build chroot." >&2
	echo "Use --help for usage information" >&2
	exit 1
fi

if [ "$1" = "-h" ] || [ "$1" = "--help" ] ; then
	echo "Login in chrooted system as builder user"
	echo "	-r - login as root"
	echo "	-n - login via network (unsupported now"
	exit 0
fi

[ "$1" = "-n" ] && { shift ; NETBUILD=1 ; } || NETBUILD=

SYS="$1"
shift

USERCO="su -"
[ "$1" = "-r" ] && shift || USERCO="su - lav"
# TODO:
[ -n "$1" ] && COMMANDTO="-c '$@\'"

#echo "Enter YOUR password below!"
export TMPDIR=/tmp
#TMP=~/tmp
#TESTDIR=/tmp/testlog-$USER
#mkdir -p $TESTDIR/
TESTDIR=`mktemp -d /tmp/autobuild/chroot-$USER-XXXXXX`

if [ -n "$NETBUILD" ] ; then
	echo Mount $SYS by network ...
	$SUDO mount borroman:/mnt/$SYS $TESTDIR -o soft || exit 1
else
	echo Mount $SYS from local...
	$SUDO mount $LINUXHOST/$SYS $TESTDIR --bind || exit 1
fi
$SUDO mkdir -p $TESTDIR/{srv/wine,proc,home/lav,dev/pts}

echo Mount local home...
$SUDO mount /srv/builder-login $TESTDIR/home/lav --bind #|| exit 1
echo Mount swine...
#$SUDO mount /usr/local/ $TESTDIR/usr/local --bind
#$SUDO mount /net/wine/ $TESTDIR/srv/wine --bind
echo Chrooting...
export HOSTNAME=$SYS
export PS1="[\u@$SYS \W]\$"
#[\u@\h \W]\$
$SUDO chroot $TESTDIR su -c "mount /proc"
$SUDO chroot $TESTDIR su -c "mount /dev/pts"
$SUDO chroot $TESTDIR $USERCO $COMMANDTO
$SUDO umount $TESTDIR/home/lav && echo "Unmount home"
#$SUDO umount $TESTDIR/usr/local $TESTDIR/srv/wine  && echo "Unmount swine"
$SUDO chroot $TESTDIR su -c "umount /proc"
$SUDO chroot $TESTDIR su -c "umount /dev/pts"
$SUDO umount $TESTDIR && echo "Unmount $SYS"
# -f not supported
rmdir $TESTDIR
