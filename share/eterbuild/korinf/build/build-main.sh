#!/bin/bash
##
#  Korinf project
#
#  Main build related functions
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


# Internal: printout args with add *.$TARGET
expand_filelist()
{
        declare -a ar
        ar=( $@ )
	#[ -z "$1" ] && return
        for i in `seq 0 $(( ${#ar[@]} - 1))`; do
                echo -n "${ar[i]}*.$TARGET "
        done
}

prepare_filelist()
{
	[ -z "$MAINFILESLIST$EXTRAFILESLIST" ] && fatal "Logical error with MAINFILESLIST EXTRAFILESLIST"
	EXPMAINFILES=`expand_filelist $MAINFILESLIST`
	EXPEXTRAFILES=`expand_filelist $EXTRAFILESLIST`

	# Hack for ALT
	# TODO: move to build script, �� ���� ����� ������ ��� rpm-build* � �������� �� etersoft-build-utils
	[ "$BUILDNAME" = "rpm-build-altlinux-compat" ] && \
		[ $dist_name = "ALTLinux" ] && EXPMAINFILES=`expand_filelist rpm-build-compat-[0-9]`

	[ -n "$ADEBUG" ] && echo "EXPMAINFILES: $EXPMAINFILES EXPEXTRAFILES: $EXPEXTRAFILES"
	[ -z "$EXPMAINFILES$EXPEXTRAFILES" ] && fatal "Logical error with EXPMAINFILES EXPEXTRAFILES"

}

build_in_dist()
{
	case $dist_name in
		"FreeBSD")
			kormod_build freebsd
			logit "build in FreeBSD $dist_ver" build_bsd || return 1
			prepare_filelist
			logit "copying built packages to $dist" copying_bsd || return 1
			[ -n "$BOOTSTRAP" ] && logit "install built" install_bsd
			logit "cleaning" cleaning_bsd || return 1
			;;

		"OpenSolaris")
			kormod_build solaris
			logit "build in Solaris $dist_ver" build_solaris || return 1
			prepare_filelist
			logit "copying built packages to $dist" copying_solaris || return 1
			logit "cleaning" cleaning_solaris || return 1
			;;

		"Gentoo")
			kormod_build gentoo
			case $dist_ver in
			    "2007")
				logit "build in Gentoo $dist_ver" build_gentoo2007 || return 1
				prepare_filelist
				logit "copying built packages to $dist" copying_gentoo2007 || return 1
				logit "cleaning in Gentoo $dist_ver" clean_gentoo2007 || return 1
				;;

			    "2006.1")
				logit "mount $dist" mount_linux || continue
				logit "build in Gentoo $dist_ver" build_emerge || return 1
				prepare_filelist
				logit "copying built packages to $dist" copying_emerge || return 1
				logit "umount" end_umount || return 1
				;;
			esac
			;;

		"ArchLinux")
			kormod_build archlinux
			kormod_build rpm
			logit "mount $dist" mount_linux || return 1
			logit "build $dist" build_rpms $dist || return 1
			logit "convert RPM to $TARGET" convert_archlinux || return 1
			prepare_filelist
			logit "copying built packages to $dist" copying_pkgbuild || return 1
			logit "umount" end_umount || return 1
			;;

		"ALTLinux")
			kormod_build hasher
			logit "build in hasher $dist_ver" build_in_hasher || return 1
			prepare_filelist
			logit "copying built packages to $dist" copying_packages || return 1
			;;

		*)
			kormod_build rpm
			logit "mount $dist" mount_linux || return 1
			logit "build $dist" build_rpms $dist || return 1
			prepare_filelist
			if [ "$TARGET" != "rpm" ] ; then
				logit "convert RPM to $TARGET" convert_rpm || return 1
			fi

			if [ -n "$BOOTSTRAP" ] ; then
				logit "install built" install_built || return 1
			fi

			logit "copying to $dist" copying_packages || return 1
			logit "umount" end_umount || return 1
			;;
	esac
}


build_src_pkg()
{
	case $dist_name in
		"FreeBSD"|"OpenSolaris"|"Gentoo")
			warning "src build for $dist_name is unsupported"
			return 1
			;;

		"ALTLinux")
			kormod_build hasher
			logit "build src.rpm" build_in_hasher || return 1
			prepare_filelist
			logit "copying to $dist" copying_packages || return 1
			;;

		*)
			kormod_build rpm
			logit "mount $dist" mount_linux || return 1
			logit "build src.rpm" build_rpms $dist || return 1
			prepare_filelist

			logit "copy built packages to $dist" copying_packages || return 1
			logit "umount" end_umount || return 1
			;;
	esac
}

