#!/bin/sh
# 2005, 2006, 2007, 2008 (c) Etersoft http://etersoft.ru
# Author: Vitaly Lipatov <lav@etersoft.ru>
# GNU Public License version 3
#
# Helper script
# �������� ������ ��� ������������� � rebuild.list ������ � �������� ������ �� �����.
# ������ ���������� �� �������������� ����������� ����������
# use with builder user
# Req: etersoft-build-utils >= 1.1, alien >= 8.63

# Example in three lines:
# . functions/helpers.sh
# export REBUILDLIST=lists/rebuild.list.all
# build_build your-package-name

#
if [ -z "$RPMBUILD" ] ; then
	. /etc/rpm/etersoft-build-functions
fi

# For compatibility: If not included jet
if [ -z "$CHROOTDIR" ] ; then
	. functions/config.in || fatal "Can't locate config.in"
fi

# FIXME: Obsoleted?
# call with full path
switch_to_builder()
{
if [ ! `id -un` = "$LOCUSER" ] ; then
	SCRIPTPATH=`realpath $1 | sed -e "s|.*/Projects/|/home/$LOCUSER/Projects/|g"`
	echo $SCRIPTPATH
	#SCRIPTPATH=/home/builder/Projects/eterbuild/`basename $1`
	shift
	echo
	echo
	echo "Restart script $SCRIPTPATH with $LOCUSER user"
	sudo su - $LOCUSER -c "$SCRIPTPATH $@" | tee $ALOGDIR/autobuild.process.log
	exit 1
fi
}

# build binary packages according to REBUILDLIST
# args: BUILDNAME
build_rpm()
{
	echo
	echo " =============================================== "
	echo >> $LOGDIR/autobuild.report.log

	local PRODUCT BUILDNAME
	# disable changelog editing
	export EDITOR=
	test -n "$1" && BUILDNAME=$1 || fatal "broken build_rpm param"

	MAINFILESLIST=$MAINFILES
	EXTRAFILESLIST=$EXTRAFILES

	# FIXME: For compatibility
	if [ -n "$2" ] ; then
		if [ "$2" = "HELPER" ] ; then
			if [ -z "$MAINFILESLIST$EXTRAFILESLIST" ] ; then
				EXTRAFILESLIST="${BUILDNAME}[-_]"
				#echo "Move package to extra dir (HELPER flag)"
			fi
		else
			fatal "Only HELPER second param is allowed"
		fi
	fi

	# Use default value for simple backward compat
	[ -z "$MAINFILESLIST$EXTRAFILESLIST" ] && MAINFILESLIST="${BUILDNAME}"

	# ��� ������������� � 1.0.7
	#if [ "$BUILDNAME" = "wine-etersoft" ] ; then
	#	BASEPATH=$WINEETER_PATH/$WINENUMVERSION
	#fi

	if [ -n "$FTPDIR" ] || [ -n "$BASEPATH" ] ; then
		warning "obsoleted: BASEPATH, FTPDIR. use SOURCEPATH, TARGETPATH instead"
		[ -n "$FTPDIR" ] && TARGETPATH=$FTPDIR
	fi

	# ��� �������������
	if [ -z "$BASEPATH" ] &&  [ -z "$SOURCEPATH" ] && [ -z "$TARGETPATH" ]; then
		BASEPATH=$WINEPUB_PATH/$WINENUMVERSION
		warning "use default BASEPATH, replace it with SOURCE/TARGET variables"
	fi

	[ -z "$SOURCEPATH" ] && SOURCEPATH=$BASEPATH/sources
	[ -z "$TARGETPATH" ] && TARGETPATH=$BASEPATH/WINE
	echo "SOURCE=$SOURCEPATH TARGET=$TARGETPATH"

	[ -n "$ADEBUG" ] && echo "BUILDNAME: $BUILDNAME PRODUCT:$PRODUCT"
	( export BUILDPKGNAME MAINFILESLIST EXTRAFILESLIST INTUSER BUILDERHOME BUILDNAME PRODUCT ADEBUG SOURCEPATH TARGETPATH ; functions/autobuild-functions.sh ) || fatal "Failed"
}

# build source packages according to REBUILDLIST
# args: BUILDNAME
build_srpm()
{
	local BUILDNAME
	# disable changelog editing
	export EDITOR=
	test -n "$1" && BUILDNAME=$1 || fatal "broken build_srpm param"
	MAKESPKG=1

	MAINFILESLIST=$MAINFILES
	EXTRAFILESLIST=$EXTRAFILES
	# Use default value for simple backward compat
	[ -z "$MAINFILESLIST$EXTRAFILESLIST" ] && MAINFILESLIST="${BUILDNAME}"

	[ -n "$ADEBUG" ] && echo "BUILDNAME: $BUILDNAME"
	( export BUILDPKGNAME MAINFILESLIST EXTRAFILESLIST INTUSER BUILDERHOME BUILDNAME ADEBUG SOURCEPATH TARGETPATH MAKESPKG; functions/autobuild-functions.sh ) || fatal "Failed"

}

