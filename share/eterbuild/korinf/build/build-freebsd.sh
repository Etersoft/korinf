#!/bin/sh
# 2005, 2006, 2007 (c) Etersoft http://etersoft.ru
# Author: Vitaly Lipatov <lav@etersoft.ru>
# GNU Public License

# BUILD - root of current system
# BUILDERHOME - absolute path to user dir in current system

# PACKAGE
build_bsd()
{
	local PREF
	PREF="/mnt/$dist_name/$dist_ver"

	echo "Copying to $FREEBSDSSH:$PREF/$FREEBSDPATH"
	ssh $FREEBSDKEY $FREEBSDSSH "mkdir -p $PREF/$FREEBSDPATH/" || { warning "Cannot create dir $FREEBSDPATH" ; return 1 ; }
	scp  $KORINFDIR/korinf/remote-scripts/remote-freebsd.sh $FREEBSDSSH:$PREF/$FREEBSDPATH/ || { warning "Cannot copy script" ; return 1 ; }
	echo "Building package..."
	ssh $FREEBSDKEY $FREEBSDSSH "sudo chroot $PREF /$FREEBSDPATH/remote-freebsd.sh build $PACKAGE $WINENUMVERSION \"$PRODUCT\" \"$ETERREGNUM\" $SOURCEURL" || { warning "Can't build" ; return 1 ; }
	true
}

copying_bsd()
{
	local PREF
	PREF="/mnt/$dist_name/$dist_ver"

	prepare_copying

	scp $FREEBSDKEY $FREEBSDSSH:$PREF/usr/ports/packages/All/$PACKAGE[-_][0-9]*.tbz $DESTDIR || { warning "Cannot copy $PACKAGE" ; return 1 ; }
	chmod g+rw -R $DESTDIR/* || true
}

cleaning_bsd()
{
	local PREF
	PREF="/mnt/$dist_name/$dist_ver"
	ssh $FREEBSDKEY $FREEBSDSSH "sudo chroot $PREF /$FREEBSDPATH/remote-freebsd.sh clean $PACKAGE $WINENUMVERSION $PRODUCT $ETERREGNUM" || { warning "Can't clean" ; return 1 ; }
}

install_bsd()
{
	local PREF
	PREF="/mnt/$dist_name/$dist_ver"
	ssh $FREEBSDKEY $FREEBSDSSH "sudo chroot $PREF /$FREEBSDPATH/remote-freebsd.sh install $PACKAGE $WINENUMVERSION $PRODUCT $ETERREGNUM" || { warning "Can't install" ; return 1 ; }
}
