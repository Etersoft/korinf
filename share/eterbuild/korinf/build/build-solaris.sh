#!/bin/sh
##
#  Korinf project
#
#  Solaris build related functions
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

# BUILD - root of current system
# BUILDERHOME - absolute path to user dir in current system

REMOTESSH=builder@solaris
REMOTEPATH=/export/home/builder/work

# PACKAGE
build_solaris()
{
	echo "Copying to Solaris"
	ssh $REMOTESSH "mkdir -p $REMOTEPATH" || { warning "Cannot create dir $REMOTEPATH" ; return 1 ; }
	scp  $KORINFDIR/korinf/remote-scripts/remote-solaris.sh $REMOTESSH:$REMOTEPATH/ || { warning "Cannot copy script" ; return 1 ; }
	echo "Building package with:"
	echo "PACKAGE:$PACKAGE WINENUMVERSION:$WINENUMVERSION ETERREGNUM:$ETERREGNUM SOURCEURL:$SOURCEURL"
	ssh $REMOTESSH "bash $REMOTEPATH/remote-solaris.sh $PACKAGE $WINENUMVERSION \"$ETERREGNUM\" $SOURCEURL" || { warning "Can't build" ; return 1 ; }
	true
}

copying_solaris()
{
	prepare_copying

	scp $REMOTESSH:/tmp/wine/ready/$PACKAGE[-_][0-9]*.pkg.gz $DESTDIR
	chmod g+rw -R $DESTDIR/* || true
}

cleaning_solaris()
{
	true
}
