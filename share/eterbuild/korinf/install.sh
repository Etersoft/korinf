#!/bin/sh
# 2005, 2006, 2007, 2008 (c) Etersoft http://etersoft.ru
# Author: Vitaly Lipatov <lav@etersoft.ru>
# GNU Public License


# install built packages
install_built()
{	
	local NODEPS
	echo "Install built $TARGET packages to $BUILDROOT root dir..."
	# Do not install debug packages
	#rm -f $BUILTRPM/*debug*
	#BUILDFILES=`echo *${BUILDNAME}*$TARGET`	
	#popd
	# Note: немного странно с кавычками и разворачиванием звёздочек
	case $TARGET in
		"deb") # Debian/Ubuntu
			$SUDO chroot $BUILDROOT su - -c "$NICE dpkg -i --force-all $INTBUILT/*${BUILDNAME}*.$TARGET"
			#$SUDO chroot $BUILD $NICE dpkg -i --force-overwrite "$INTBUILT/*${BUILDNAME}*.$TARGET"
			RES=$?
			;;
		"tgz") # Slackware
			$SUDO chroot $BUILDROOT $NICE installpkg "$INTBUILT/*${BUILDNAME}*.$TARGET"
			RES=$?
			;;
		"tar.gz") # Hack for ArchLinux
			#$SUDO chroot $BUILDROOT su - -c "$NICE pacman -A --force --nodeps $INTBUILT/*${BUILDNAME}*.$TARGET"
			$SUDO chroot $BUILDROOT su - -c "cd / ; ls -1 $INTBUILT/*${BUILDNAME}*.$TARGET | xargs -n1 --no-run-if-empty $NICE tar xfvz "
			RES=$?
			;;
		*)
			# First time install without dependences
			# DURING_INSTALL for disable start_service
			[ -n "$WITHOUTEBU" ] && NODEPS=--nodeps
			$SUDO chroot $BUILDROOT su - -c "cd $INTBUILT && DURING_INSTALL=1 $NICE rpm -Uvh ${EXPMAINFILES} ${EXPEXTRAFILES} --force $NODEPS"
			RES=$?
			#[ "$RES" = "0" ] || warning "install status: failed"
			# Hack: broken return status on some systems
			#RES=0
			;;
	esac
	return $RES
}

# install required packages for build
install_req()
{
	echo
}
