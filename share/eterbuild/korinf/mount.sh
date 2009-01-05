#!/bin/bash
# 2005, 2006, 2007 (c) Etersoft http://etersoft.ru
# Author: Vitaly Lipatov <lav@etersoft.ru>
# GNU Public License version 3
#

mount_linux()
{
	local MOUNTPARAM

	# Создаём необходимые каталоги
	BUILDROOT=`mktemp -d $CHROOTDIR/$dist_name-XXXXXX`
	BUILDERHOME=$BUILDROOT-home
	mkdir -p $BUILDERHOME/{,tmp,RPM,RPM/BUILD,RPM/RPMS} || fatal "Can't create $BUILDERHOME"
	chmod g+rwx $BUILDROOT $BUILDERHOME
	$SUDO chown $LOCUSER $BUILDERHOME -R

	echo "Mount $LINUXHOST/$dist to $BUILDROOT..."
	[ -z "$BUILDROOT" ] && echo "Skip mount due empty BUILDROOT" && return 1
	[ -d $LINUXHOST ] && MOUNTPARAM="--bind" || MOUNTPARAM="-o soft"
	$SUDO mount $LINUXHOST/$dist $BUILDROOT $MOUNTPARAM || { warning "Cannot mount..." ; return 1 ; }
	$SUDO chmod o+rx $BUILDROOT
	ls -l $BUILDROOT
	test -d $BUILDROOT/etc/ || fatal "Linux system is missed in $BUILDROOT"

	$SUDO su - $LOCUSER -c "mkdir -p $BUILDROOT/{proc,home/$INTUSER,srv/wine}"
	echo Mount proc...
	$SUDO mount -t proc proc $BUILDROOT/proc || { warning "Cannot mount proc" ; return 1 ; }

	echo Mount local home...
	$SUDO mount $BUILDERHOME $BUILDROOT/home/$INTUSER --bind || { warning "Cannot mount home" ; return 1 ; }

	#echo Mount srv/wine...
	#$SUDO mount /net/wine $BUILD/srv/wine --bind || { warning "Cannot mount home" ; return 0 ; }
}	

end_umount()
{
	local i u ERR
	ERR=0
	[ -z "$BUILDROOT" ] && echo "Skip umount due empty BUILDROOT" && return 1
	echo "Unmounting and cleaning..."
	for i in /proc/bus/usb /proc/sys/fs/binfmt_misc /proc /home/$INTUSER / ; do
		u=$BUILDROOT$i
		if [ -d $u ] && mount | grep $i >/dev/null ; then
			$SUDO umount -v $u || $SUDO fuser -v $u
			#|| echo "Failed $u umount"
			#$SUDO umount $i || $SUDO umount $i -l || ERR=1
		fi
	done
	[ $ERR = 0 ] && echo "DONE" || echo "Umount FAILED"
	if [ -z "$ADEBUG" ] ; then
		echo "Removing $BUILDROOT $BUILDERHOME ..."
		$SUDO su - $LOCUSER -c "rm -rf $BUILDERHOME" || ERR=1
		$SUDO su - $LOCUSER -c "rmdir $BUILDROOT" || ERR=1
		[ $ERR = 0 ] && echo "DONE" || echo "Removing FAILED"
	else
		echo "Skip removing due ADEBUG set"
	fi
	BUILDROOT=""
	return $ERR
}

