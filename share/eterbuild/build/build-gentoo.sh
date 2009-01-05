#!/bin/sh
# 2005, 2006, 2007 (c) Etersoft http://etersoft.ru
# Author: Vitaly Lipatov <lav@etersoft.ru>
# GNU Public License

# BUILDROOT - root of current system
# BUILDERHOME - absolute path to user dir in current system

#WORKDIR=$(dirname $0)
#WORKDIR=.

# TODO: user dist_ver

REMOTESSHG7=builder@gentoo
REMOTEPATHG7=/home/builder/work


build_emerge()
{
	local RET
	echo "Copying to $BUILDROOT/tmp"
	cp -f functions/remote-gentoo.sh $BUILDROOT/tmp || { warning "Cannot copy script" ; return 1 ; }
	$SUDO chroot $BUILDROOT su - -c "$NICE sh /tmp/remote-gentoo.sh \"$PACKAGE\" \"$WINENUMVERSION\" \"$PRODUCT\" \"$ETERREGNUM\" \"$SOURCEURL\""
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

	cp -f $BUILDROOT/usr/portage/packages/All/$EPACKAGE*.tbz2 $DESTDIR || { warning "Cannot copy packages" ; return 1; }

	chmod g+rw -R $DESTDIR/* || true

}

build_gentoo2007()
{
        echo "Copying to Gentoo 2007"
        ssh $REMOTESSHG7 "mkdir -p $REMOTEPATHG7" || { warning "Cannot create dir $REMOTEPATHG7" ; return 1 ; }
        scp ~/Projects/eterbuild/functions/remote-gentoo.sh $REMOTESSHG7:$REMOTEPATHG7/ || { warning "Cannot copy script to remote server" ; return 1 ; }
        echo "Building package..."
        ssh $REMOTESSHG7 "bash $REMOTEPATHG7/remote-gentoo.sh \"$PACKAGE\" \"$WINENUMVERSION\" \"$PRODUCT\" \"$ETERREGNUM\" \"$SOURCEURL\"" || { warning "Can't build" ; return 1 ; }
        true
}

copying_gentoo2007()
{
        prepare_copying

	scp $REMOTESSHG7:/usr/portage/packages/All/$EPACKAGE*.tbz2 $DESTDIR
        chmod g+rw -R $DESTDIR/* || true
}

clean_gentoo2007()
{
        true
}