#!/bin/sh
# 2005, 2006, 2007, 2008, 2009 (c) Etersoft http://etersoft.ru
# Author: Vitaly Lipatov <lav@etersoft.ru>
# GNU Public License version 3

# Run with [-s] [System/Version] [ProjectVersion]
#   System/Version - ALTLinux/5.0 for example
#   ProjectVersion - 1.0.9 or unstable for example

#
# load common functions, compatible with local and installed script
. `dirname $0`/../share/eterbuild/korinf/common
kormod korinf


build_extrapkg()
{
	EXTRAFILES="$1"
	shift
	build_project $WINEPUB_PATH "$EXTRAFILES" WINE $PROJVER $@
}

# install packages after build
BOOTSTRAP=1

# Run with -s for real bootstrap
if [ "$1" = "-s" ] ; then
	WITHOUTEBU=1
	NIGHTBUILD=1
	shift
fi

if [ -n "$WITHOUTEBU" ] ; then
	# Build without etersoft-build-utils using (just rpm -bb)
	# FIXME: broken error code
	build_extrapkg rpm-build-altlinux-compat $@ || exit 1
	build_extrapkg etersoft-build-utils $@ || exit 1
fi


# Hack due overrides from WITHOUTEBU mode
RPMSDIR=RPM/BP/RPMS

# Build with etersoft-build-utils (rpmbb using)
WITHOUTEBU=
build_extrapkg rpm-build-altlinux-compat $@
build_extrapkg etersoft-build-utils $@
