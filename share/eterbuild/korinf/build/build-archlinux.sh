#!/bin/sh
##
#  Korinf project
#
#  Arch Linux build related functions
#
#  Copyright (c) Etersoft <http://etersoft.ru> 2005, 2006, 2007, 2009
#  Copyright (c) Vitaly Lipatov <lav@etersoft.ru> 2009
#
#  This program is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 3 of the License, or
#  (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program.  If not, see <http://www.gnu.org/licenses/>.
##

# BUILDROOT - root of current system
# BUILDERHOME - absolute path to user dir in current system

# TODO: user dist_ver

convert_archlinux()
{
	export PACKAGE
	local RET
	echo "Copying to $BUILDROOT/tmp"
	cp -f  $KORINFDIR/korinf/remote-scripts/remote-archlinux-rpm.sh $BUILDROOT/tmp || { warning "Cannot copy script" ; return 1 ; }
	echo "chrooting and converting"
#	$SUDO chroot $BUILDROOT /bin/sh -c '/bin/su -l -c "$NICE sh -x /tmp/remote-archlinux-rpm.sh \"$PACKAGE\"" lav'
	$SUDO chroot $BUILDROOT su -l -c "sh -x /tmp/remote-archlinux-rpm.sh \"$PACKAGE\" \"$BUILDNAME\"" $INTUSER
	RET=$?
	if [ $RET != 0 ] ; then
		warning "Can't build"
		#cat $BUILDROOT/var/tmp/portage/app-emulation/$PACKAGE-*/temp/build.log
		return 1
	fi
	true
}

copying_pkgbuild()
{
	prepare_copying

	cp -f $BUILDROOT/home/lav/abs/$BUILDNAME/*$BUILDNAME*.pkg* $DESTDIR || { warning "Cannot copy packages" ; return 1; }

	chmod g+rw -R $DESTDIR/* || true

}

#exit 0