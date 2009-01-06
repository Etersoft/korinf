#!/bin/sh
# 2005, 2006, 2007 (c) Etersoft http://etersoft.ru
# Author: Vitaly Lipatov <lav@etersoft.ru>
# GNU Public License version 3

# Build packages in hasher
function build_in_hasher()
{
	# default for ALT Linux
	TARGET="rpm"

	# convert to etersoft-build-utils notation
	dist_mod=`echo $dist_ver | sed -e "s|2\.4|M24|g" |
		sed -e "s|2\.3|M23|g" | sed -e "s|3\.0|M30|g" |
		sed -e "s|4\.0|M40|g" | sed -e "s|4\.1|M41|g" | sed -e "s|Sisyphus|SS|g"`
	set_target_type $dist_mod
	detect_target_env >>$LOGFILE 2>&1
	BUILTRPM=$HASHERDIR$MENVARG/repo/i586/RPMS.hasher

	test -n "$MENV" || fatal "build_in_hasher: Call me with correct MENV variable"
	echo "Build in hasher: $MENV for $dist ..."
	if [ -n "$NIGHTBUILD" ] && [ $BUILDNAME = "rpm-build-altlinux-compat" ] ; then
		echo "Clean hasher's rpms before nightbuild"
		rm -rf $BUILTRPM/*
	else
		echo "Clean only the same names from hasher"
		rm -rf $BUILTRPM/*${BUILDNAME}*
	fi

	rm -f $BUILDERHOME/buildenv.txt

	# FIXME: rewrite spec in hasher?
	# we need .rpmmacros for rpmbph/rpmbsh
	#sed -e "s|$INTUSER|$USER|g" < $WINEETER_PATH/sources/rpmmacros >~/.rpmmacros || fatal "Can't copy macros"
if [ ! -r ~/.rpmmacros ] ; then
cat <<EOF >~/.rpmmacros || fatal "Can't copy macros"
%_topdir        /home/$USER/RPM
%_tmppath       /home/$USER/tmp
%_sourcedir %_topdir/SOURCES
%vendor Etersoft
%distribution WINE@Etersoft
#%_target_cpu i586
%buildhost builder.etersoft.ru
#%BuildRoot: %_tmppath
#%_gpg_path %homedir/.gnupg
#%_gpg_name Vitaly Lipatov <lav@altlinux.ru>
#%packager Vitaly Lipatov <lav@altlinux.ru>
%packager Etersoft Builder <support@etersoft.ru>

# see http://wiki.sisyphus.ru/devel/RpmSetup
%_build_name_fmt %{NAME}-%{VERSION}-%{RELEASE}.%{ARCH}.rpm
EOF
fi

	#detect_target_env
	# We install here in builder user home
	rpm -iv $BUILDSRPM || return 1;
	subst "s|@ETERREGNUM@|${ETERREGNUM}|g" $RPMDIR/SPECS/$BUILDNAME.spec

if [ ! -r ~/.ebconfig ] ; then
	cat >~/.ebconfig <<EOF
HASHER_NOCHECK=nvr,gpg,packager,changelog,deps
#TODO: специальный репозиторий без updates
APTCONFBASE=$WORKDIR/apt/apt.conf
EOF
fi

	# Hack for kernel module packages
	if [ "$BUILDNAME" = "haspd" ] ; then
		case $MENV in
			M24)
				NEEDEDKERNEL="kernel-headers-modules-std26-smp kernel-headers-modules-std26-up"
				;;
			M30)
				#NEEDEDKERNEL="kernel-headers-modules-std26-smp kernel-headers-modules-std26-up"
				# Не знаю, почему не берёт:
				# error: failed build dependencies:
				#        kernel-headers-std26-up >= 2.6.12-alt10 is needed by haspd-2.0-alt0.M30.2

				#NEEDEDKERNEL="kernel-headers-std26-up >= 2.6.12-alt10 kernel-headers-std26-smp >= 2.6.12-alt10"
				#NEEDEDKERNEL="$NEEDEDKERNEL kernel-headers-modules-std26-up >= 2.6.12-alt10 kernel-headers-modules-std26-smp >= 2.6.12-alt10"
				NEEDEDKERNEL="$NEEDEDKERNEL kernel-headers-std26-up = 2.6.12-alt6 kernel-headers-std26-smp = 2.6.12-alt6"
				NEEDEDKERNEL="$NEEDEDKERNEL kernel-headers-modules-std26-up = 2.6.12-alt6 kernel-headers-modules-std26-smp = 2.6.12-alt6"
				;;
			M40)
				NEEDEDKERNEL="kernel-headers-modules-std-smp kernel-headers-modules-std-pae kernel-headers-modules-ovz-smp kernel-headers-modules-wks-smp"
				;;
			M41)
				NEEDEDKERNEL="kernel-headers-modules-std-smp kernel-headers-modules-std-pae kernel-headers-modules-ovz-smp"
				;;
						#kernel-headers-modules-wks-smp"
			SS)
				NEEDEDKERNEL="kernel-headers-modules-std-pae kernel-headers-modules-ovz-smp kernel-headers-modules-std-def"
						#kernel-headers-modules-std-smp
				;;
		esac
		# Add selected kernel requires
		subst "1iBuildRequires: $NEEDEDKERNEL" $RPMDIR/SPECS/$BUILDNAME.spec
	fi

	# ALC 2.3
	if [ "$MENV" = "M23" ] ; then
		echo "Add cvs buildrequires for $MENV"
		subst "1iBuildRequires: cvs" $RPMDIR/SPECS/$BUILDNAME.spec
	fi

	# Hack against broken glibc in Compact 3.0
	if [ "$MENV" = "M30" -a "$BUILDNAME" = "wine" ] ; then
		echo "Add glibc requires for $MENV"
		subst "1iRequires: glibc-core-i686" $RPMDIR/SPECS/$BUILDNAME.spec
	fi

	# build source package
	if [ -n "$MAKESPKG" ] ; then
		BUILTRPM=$RPMDIR/SRPMS
		if [ "$MENV" = "SS" ] ; then
			# disable 20.07.06 due prelink orphaned in Sisyphus, 04.04.07 prelink returned
			subst "1iBuildRequires: prelink" $RPMDIR/SPECS/$BUILDNAME.spec
			rpmbs -s $RPMDIR/SPECS/$BUILDNAME.spec || { warning "Cannot build srpm" ; return 1 ; }
		else
			[ "$MENV" != "M23" ] && subst "1iBuildRequires: prelink" $RPMDIR/SPECS/$BUILDNAME.spec
			rpmbph -n $MENVARG $RPMDIR/SPECS/$BUILDNAME.spec || { warning "Cannot build srpm" ; return 1 ; }
		fi
		return
	fi

	# build binary packages
	if [ "$MENV" = "SS" ] ; then
		# disable 20.07.06 due prelink orphaned in Sisyphus, 04.04.07 prelink returned
		subst "1iBuildRequires: prelink" $RPMDIR/SPECS/$BUILDNAME.spec
		rpmbsh $RPMDIR/SPECS/$BUILDNAME.spec || { warning "Cannot hashered" ; return 1 ; }
	else
		# TODO для M?? собираем пока из спека а не из пакета...
		# но из спека пользователя builder :)
		#myhsh $MENVARG $BUILDSRPM
		# FIXME: if_with does not work in Debian, Special...
		[ "$MENV" != "M23" ] && subst "1iBuildRequires: prelink" $RPMDIR/SPECS/$BUILDNAME.spec
		rpmbph $MENVARG $RPMDIR/SPECS/$BUILDNAME.spec || { warning "Cannot hashered" ; return 1 ; }
	fi
}
