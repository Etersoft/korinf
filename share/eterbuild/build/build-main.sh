#!/bin/bash
# 2005, 2006, 2007 (c) Etersoft http://etersoft.ru
# Author: Vitaly Lipatov <lav@etersoft.ru>
# GNU Public License version 3

# printout args with add *.$TARGET
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
	# TODO: move to build script, но ведь можно только как rpm-build* и разнести от etersoft-build-utils
	[ "$BUILDNAME" = "rpm-build-altlinux-compat" ] && \
		[ $dist_name = "ALTLinux" ] && EXPMAINFILES=`expand_filelist rpm-build-compat-[0-9]`

	[ -n "$ADEBUG" ] && echo "EXPMAINFILES: $EXPMAINFILES EXPEXTRAFILES: $EXPEXTRAFILES"
	[ -z "$EXPMAINFILES$EXPEXTRAFILES" ] && fatal "Logical error with EXPMAINFILES EXPEXTRAFILES"

}

build_in_dist()
{
	case $dist_name in
		"FreeBSD")
			. ./functions/build-freebsd.sh
			logit "build in FreeBSD $dist_ver" build_bsd || return 1
			prepare_filelist
			logit "copying built packages to $dist" copying_bsd || return 1
			[ -n "$BOOTSTRAP" ] && logit "install built" install_bsd
			logit "cleaning" cleaning_bsd || return 1
			;;

		"OpenSolaris")
			. ./functions/build-solaris.sh
			logit "build in Solaris $dist_ver" build_solaris || return 1
			prepare_filelist
			logit "copying built packages to $dist" copying_solaris || return 1
			logit "cleaning" cleaning_solaris || return 1
			;;

		"Gentoo")
			. ./functions/build-gentoo.sh
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

		"ALTLinux")
			. ./functions/build-hasher.sh
			logit "build in hasher $dist_ver" build_in_hasher || return 1
			prepare_filelist
			logit "copying built packages to $dist" copying_packages || return 1
			;;

		*)
			. ./functions/build-rpm.sh
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
			. ./functions/build-hasher.sh
			logit "build src.rpm" build_in_hasher || return 1
			prepare_filelist
			logit "copying to $dist" copying_packages || return 1
			;;

		*)
			. ./functions/build-rpm.sh
			logit "mount $dist" mount_linux || return 1
			logit "build src.rpm" build_rpms $dist || return 1
			prepare_filelist

			logit "copy built packages to $dist" copying_packages || return 1
			logit "umount" end_umount || return 1
			;;
	esac
}

