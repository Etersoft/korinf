#!/bin/sh
##
#  Korinf project
#
#  Gentoo build related functions
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

# BUILDROOT - root of current system
# BUILDERHOME - absolute path to user dir in current system

# TODO: user dist_ver

REMOTESSHG7=$LOCUSER@gentoo
REMOTEPATHG7=/home/$LOCUSER/work

build_emerge()
{
	local RET
	echo "Copying to $BUILDROOT/tmp"
	cp -f  $KORINFDIR/korinf/remote-scripts/remote-gentoo.sh $BUILDROOT/tmp || { warning "Cannot copy script" ; return 1 ; }
	$SUDO chroot $BUILDROOT su - -c "$NICE sh /tmp/remote-gentoo.sh \"$PACKAGE\" \"$ETERREGNUM\" \"$SOURCEURL\""
	RET=$?
	if [ $RET != 0 ] ; then
		warning "Can't build"
		#cat $BUILDROOT/var/tmp/portage/app-emulation/$PACKAGE-*/temp/build.log
		return 1
	fi
	true
}

copying_emerge()
{
	prepare_copying

	cp -f $BUILDROOT/usr/portage/packages/All/$PACKAGE*.tbz2 $DESTDIR || { warning "Cannot copy packages" ; return 1; }

	chmod g+rw -R $DESTDIR/* || true

}

build_gentoo2007()
{
        echo "Copying to Gentoo 2007"
        ssh -i $PRIVATESSHKEY $REMOTESSHG7 "mkdir -p $REMOTEPATHG7" || { warning "Cannot create dir $REMOTEPATHG7" ; return 1 ; }
        scp -i $PRIVATESSHKEY $KORINFDIR/korinf/remote-scripts/remote-gentoo.sh $REMOTESSHG7:$REMOTEPATHG7/ || { warning "Cannot copy script to remote server" ; return 1 ; }
        echo "Building package..."
        ssh -i $PRIVATESSHKEY $REMOTESSHG7 "bash $REMOTEPATHG7/remote-gentoo.sh \"$PACKAGE\" \"$ETERREGNUM\" \"$SOURCEURL\"" || { warning "Can't build" ; return 1 ; }
        true
}

copying_gentoo2007()
{
        prepare_copying

        scp -i $PRIVATESSHKEY $REMOTESSHG7:/usr/portage/packages/All/$PACKAGE*.tbz2 $DESTDIR
        chmod g+rw -R $DESTDIR/* || true
}

clean_gentoo2007()
{
        true
}
