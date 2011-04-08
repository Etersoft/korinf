#!/bin/bash

##
#  Korinf project
#
#  Run script task on all systems
#  Usage: ./run-script.sh DISTR_LIST TASK [ARGS]
#  TASK - file from scripts/
#
#  Copyright (c) Etersoft <http://etersoft.ru> 2009, 2011
#  Copyright (c) Vitaly Lipatov <lav@etersoft.ru> 2009, 2011
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

kormod list

SUDO="sudo"
if [ "$UID" = "0" ]; then
	SUDO=""
fi


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

if echo $SYS | grep x86_64 >/dev/null ; then
    BUILDARCH="x86_64"
else
    BUILDARCH="i586"
fi

echo
echo
echo "==================================="
echo "Chrooting in $SYS system with $BUILDARCH arch"

if [ "$SYSARCH" != "$BUILDARCH" ] ; then
    echo "Please login to $BUILDARCH arch from a machine with the same arch (you TRY from $SYSARCH)"
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

REBUILDLIST=$1
set_rebuildlist
shift
CMDRE=$(get_distro_list $REBUILDLIST)
[ -z "$CMDRE" ] && fatal "build list is empty"

TASK=$1
[ -n "$TASK" ] && [ -f "scripts/$TASK" ] || exit 1
shift


for SYS in $CMDRE ; do
    cp -af scripts/$TASK $LOCALLINUXFARM/$SYS/tmp/remote-script.sh || continue
    chroot_in /tmp/remote-script.sh "$@"
done

