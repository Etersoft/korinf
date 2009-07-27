#!/bin/bash

##
#  Korinf project
#
#  Run script task on all systems
#  Usage: ./run-script.sh TASK
#  TASK - file from scripts/
#
#  Copyright (c) Etersoft <http://etersoft.ru> 2009
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

# load common functions, compatible with local and installed script
#. `dirname $0`/../../share/eterbuild/korinf/common
. /usr/share/eterbuild/korinf/common

SUDO="sudo"
if [ $UID = "0" ]; then
	SUDO=""
fi

print_distro()
{
	( cd /net/os/stable ; find -L ./$1 -maxdepth 2 -mindepth 2 -type d | sed -e "s|^./||" | sort | grep -v Windows | sed -e "s|^i586/||g" )
}


chroot_in()
{
COMMANDTO="$@"
TESTDIR=`mktemp -d /tmp/autobuild/chroot-$USER-XXXXXX`

[ -x "$LOCALLINUXFARM/$SYS/bin/sh" ] || return
#[ -x "$LOCALLINUXFARM/$SYS/root" ] || return

echo Mount $SYS from local...
$SUDO mount $LOCALLINUXFARM/$SYS $TESTDIR --bind || return
$SUDO mkdir -p $TESTDIR/{srv/wine,proc,home/$INTUSER,dev/pts}

#echo Mount local home...
#BUILDERHOME=$TESTDIR/home/$INTUSER
#$SUDO mount /srv/builder-login $BUILDERHOME --bind #|| exit 1
#init_home

BUILDARCH=$DEFAULTARCH
if echo $SYS | grep x86_64 >/dev/null ; then
    BUILDARCH="x86_64"
else
    BUILDARCH="i586"
fi
echo
echo
echo "==================================="
echo "Chrooting in $SYS system with $BUILDARCH arch"
# FIXME: why not DEFAULTARCH?
REALARCH=$(uname -m)
[ "$REALARCH" = "i686" ] && REALARCH="i586"
if [ "$REALARCH" != "$BUILDARCH" ] ; then
    echo "Please login to $BUILDARCH arch from a machine with the same arch (you TRY from $REALARCH)"
    exit 1
fi

USERCO="su -"
export HOSTNAME=$SYS
export PS1="[\u@$SYS \W]\$"
#[\u@\h \W]\$
$SUDO chroot $TESTDIR su -c "mount -t proc none /proc"
$SUDO chroot $TESTDIR su -c "mount -t devpts none /dev/pts"
setarch $BUILDARCH $SUDO chroot $TESTDIR sh $COMMANDTO
#$SUDO umount $TESTDIR/home/$INTUSER && echo "Unmount home"
#$SUDO umount $TESTDIR/usr/local $TESTDIR/srv/wine  && echo "Unmount swine"
$SUDO chroot $TESTDIR su -c "umount /dev/pts"
$SUDO chroot $TESTDIR su -c "umount /proc"
$SUDO umount $TESTDIR && echo "Unmount $SYS"
# -f not supported
rmdir $TESTDIR
}

TASK=$1

[ -n "$TASK" ] || exit 1

if [ -n "$2" ] ; then
	DISTR_LIST="$2"
else
	DISTR_LIST=`print_distro $DEFAULTARCH`
fi

for SYS in $DISTR_LIST ; do
    #echo $SYS
    cp -af scripts/$TASK $LOCALLINUXFARM/$SYS/tmp/remote-script.sh || continue
    chroot_in /tmp/remote-script.sh
done

