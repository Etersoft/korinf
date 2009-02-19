#!/bin/sh
##
#  Korinf project
#
#  Common rpm build packages in chrooted Linux system
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

# We hope here BUILDERHOME is clean already

INTBUILT=/home/$INTUSER/RPM/RPMS

build_rpms()
{
	local dist
	dist=$1

	BUILTRPM=$BUILDERHOME/RPM/RPMS
	TARGET=`ROOTDIR=$BUILDROOT /usr/bin/distr_vendor -p`
	[ -z "$TARGET" ] && { warning "TARGET is empty" ; return 1 ; }
	BUILDARCH="i586"
	if echo $dist | grep x86_64 >/dev/null ; then
	    BUILDARCH="x86_64"
	fi
	echo "Build '$BUILDSRPM' in chrooted $BUILDARCH system for $dist"

	cp -f $BUILDSRPM $BUILDERHOME/tmp/$BUILDNAME.src.rpm || { warning "Can't copy src.rpm" ; return 1 ; }
	$SUDO chown $LOCUSER $BUILDERHOME/tmp/$BUILDNAME.src.rpm

	# FIXME: ebconfig is obsolete
	[ -r $BUILDERHOME/.ebconfig ] || echo "RPMBUILD=rpmbuild" > $BUILDERHOME/.ebconfig

if [ ! -r $BUILDERHOME/.rpmmacros ] ; then
cat <<EOF >$BUILDERHOME/.rpmmacros || fatal "Can't copy macros"
# Etersoft's default macros
%_topdir        /home/$INTUSER/RPM
%_tmppath       /home/$INTUSER/tmp
%_sourcedir %_topdir/SOURCES
%vendor Etersoft
%distribution WINE@Etersoft
#%_target_cpu i586
%buildhost builder.etersoft.ru
# do wrong (crossed with --buildroot?
#%BuildRoot: %_tmppath/%{name}-%{version}
#%buildroot: %_tmppath/%{name}-%{version}
%packager Etersoft Builder <support@etersoft.ru>

# see http://wiki.sisyphus.ru/devel/RpmSetup
%_build_name_fmt %{NAME}-%{VERSION}-%{RELEASE}.%{ARCH}.rpm
EOF
fi

	# TODO: rewrite
	#KERVERFILE=$BUILDROOT/etc/rpm/kernel_version

	# For log purposes
	ls -l $BUILDROOT/etc/rpm

	if [ -n "$WITHOUTEBU" ] ; then
		echo "Use emergency or first build mode"
		# FIXME: add buildroot?
		CMDBUILD="rpmbuild -bb --nodeps ~/RPM/SPECS/$BUILDNAME.spec"
	else
		if [ -z "$NOREPL" ] ; then
			CMDBUILD="rpmbph -v ~/RPM/SPECS/$BUILDNAME.spec"
		else
			CMDBUILD="rpmbb ~/RPM/SPECS/$BUILDNAME.spec"
		fi
	fi

	if [ -n "$MAKESPKG" ] ; then
		BUILTRPM=$BUILDERHOME/RPM/SRPMS
		CMDBUILD="rpmbph -n -v ~/RPM/SPECS/$BUILDNAME.spec"
	fi

	#CMDREPORT="( LANG=C winelog -c ; cat ~/.rpmmacros ) >~/buildenv.txt"
	CMDAFTERREPORT="( head -n 5 /usr/bin/rpmbph ; cat ~/RPM/SPECS/LOCAL/$BUILDNAME.spec ; echo "-------" ; rpm --showrc ; echo "-----"; cat ~/RPM/BUILD/${BUILDNAME}*/config.log ; cat ~/RPM/BUILD/${BUILDNAME}*/include/config.h ; rpm -qa )  >>~/buildenv.txt"
	#CMDREPORT="echo; cat ~/RPM/SPECS/$BUILDNAME.spec ; echo"
	CMDREPORT="true"

	# TODO: set defattr after each files section
	# awk 'BEGIN{desk=0}{print;if(/^%build/&&desk==0){printf("%s\n\n", text);desk++}}' text="$RECONFT"

        LOGFAILFILE="$BUILDERHOME/RPM/log/$BUILDNAME.log.failed"
	rm -f "$LOGFAILFILE"

	echo Chrooting as $INTUSER...
	# copy src.rpm into build system and build
	RPMCOMMAND=rpm
	# Use rpm.static if exist (due ALT's src.rpm has too old version)"
	[ -x "$BUILDROOT/usr/bin/rpm.static" ] && RPMCOMMAND=/usr/bin/rpm.static
	$NICE setarch $BUILDARCH $SUDO chroot $BUILDROOT \
		su - $INTUSER -c "export LANG=C ; umask 002 ; mkdir -p ~/RPM/SRPMS ; $RPMCOMMAND -i ~/tmp/$BUILDNAME.src.rpm ; $CMDREPORT ; subst 's|@ETERREGNUM@|${ETERREGNUM}|g' ~/RPM/SPECS/$BUILDNAME.spec ; $CMDBUILD || touch ~/RPM/log/$BUILDNAME.log.failed ; $CMDAFTERREPORT"

	cat $BUILDERHOME/buildenv.txt | sed -e "s|[0-9A-F]\{4\}-[0-9A-F]\{4\}|XxXX-XxXX|g" >$LOGDIR/$BUILDNAME.cenv.log

	[ -r "$LOGFAILFILE" ] && { rm -f "$LOGFAILFILE" ; warning "build failed" ; return 1 ; }

	# workaround again flow target dirs
	pushd $BUILTRPM
	test -d i586 && mv -f i586/* ./
	test -d noarch && mv -f noarch/* ./
	popd
	return 0
}


# Only with $TARGET
convert_rpm()
{
	pushd $BUILTRPM
	ls -l
	echo "Make target packages for $TARGET"
	TODEL=`echo *${BUILDNAME}*`
	#echo "To del: $TODEL"
	# FIXME: do not return result code
	case $TARGET in
		"deb")
			$SUDO chroot $BUILDROOT su - $INTUSER -c "cd $INTBUILT; ls -l ; fakeroot alien --keep-version --scripts --veryverbose --to-$TARGET *${BUILDNAME}*.rpm ; ls -l" || { warning "alien problem with deb"; popd ; return 1 ; }
			;;
		"tgz")
			# Slackware
			fakeroot alien --keep-version --veryverbose --to-$TARGET *${BUILDNAME}*.rpm || { warning "alien problem with tgz"; popd; return 1 ; }
			;;
		"tar.gz")
			# ArchLinux
			fakeroot alien --keep-version --veryverbose --to-tgz *${BUILDNAME}*.rpm || { warning "alien problem with tar.gz"; popd; return 1 ; }
			for i in *${BUILDNAME}*.tgz ; do mv $i `basename $i .tgz`.tar.gz ; done
			;;
		*)
			warning "unknown $TARGET" ; popd; return 1;
	esac
	#echo "To del: $TODEL"
	#[ "$TARGET" = "deb" ] && $SUDO chroot $BUILD su - $INTUSER /usr/bin/dpkg -i $INTBUILT/*${BUILDNAME}*.$TARGET
	# uncomment me!
	#rm -f $TODEL
	popd
	echo "fakeroot do not returns correct result"
	return 0
}

