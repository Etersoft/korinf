#!/bin/sh
# 2005, 2006, 2007, 2008 (c) Etersoft http://etersoft.ru
# Author: Vitaly Lipatov <lav@etersoft.ru>
# GNU Public License
#
# Script for Wine School release
VERSION=0.9.8

#
. functions/helpers.sh

build_system()
{
	export REBUILDLIST="$DISTR"
	export TARGETPRIVPATH=/var/ftp/pub/download/WINE-SCHOOL/$VERSION-$PREF/RPMS
	export SOURCEPATH=/var/ftp/pvt/Etersoft/School/sources

	export MAINFILES="wine-school[-_][0-9] libwine-school[-_][0-9] libwine-school-gl[-_][0-9]"
	export EXTRAFILES="libwine-school-devel[-_][0-9] libwine-school-twain[-_][0-9]"
# libwine-school-doc[-_][0-9]"

	#build_rpm wine-school

	#build_rpm wine-school-components

	build_rpm cabextract
}

build_system_source()
{
	export REBUILDLIST="$DISTR"
	export TARGETPRIVPATH=/var/ftp/pub/download/WINE-SCHOOL/$VERSION-$PREF/SRPMS
	export SOURCEPATH=/var/ftp/pvt/Etersoft/School/sources

	#build_srpm wine-school

	#build_srpm wine-school-components

	#build_srpm rpm-build-altlinux-compat
	#build_srpm etersoft-build-utils

	build_srpm cabextract
}

#LIST="CentOS/5 ALTLinux/4.0"
LIST="CentOS/5"
PREF="Nau"
#PREF="Alt"
#LIST="ALTLinux/4.0"
for i in $LIST ; do
	DISTR="$i"
	build_system
	build_system_source
done


