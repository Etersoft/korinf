#!/bin/sh
# 2005, 2006, 2007 (c) Etersoft http://etersoft.ru
# Author: Vitaly Lipatov <lav@etersoft.ru>
# GNU Public License

# Build packages in chrooted Linux system
# We hope here BUILDERHOME is clean already

INTBUILT=/home/$INTUSER/RPM/RPMS

build_rpms()
{
	local dist
	dist=$1

	BUILTRPM=$BUILDERHOME/RPM/RPMS
	TARGET=`ROOTDIR=$BUILDROOT /usr/bin/distr_vendor -p`
	[ -z "$TARGET" ] && { warning "TARGET is empty" ; return 1 ; }

	echo "Build '$BUILDSRPM' in chrooted system for $dist"

	cp -f $BUILDSRPM $BUILDERHOME/tmp/$BUILDNAME.src.rpm || { warning "Can't copy src.rpm" ; return 1 ; }
	$SUDO chown $LOCUSER $BUILDERHOME/tmp/$BUILDNAME.src.rpm

	#install -m644 $WINEETER_PATH/sources/rpmmacros $BUILDERHOME/.rpmmacros || fatal "Can't copy macros"
	[ -r $BUILDERHOME/.ebconfig ] || echo "RPMBUILD=rpmbuild" > $BUILDERHOME/.ebconfig

if true || [ ! -r $BUILDERHOME/.rpmmacros ] ; then
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
		CMDBUILD="LANG=C $NICE rpmbuild -bb --nodeps ~/RPM/SPECS/$BUILDNAME.spec"
	else
		if [ -z "$NOREPL" ] ; then
			CMDBUILD="LANG=C $NICE rpmbph -v ~/RPM/SPECS/$BUILDNAME.spec"
		else
			CMDBUILD="LANG=C $NICE rpmbb ~/RPM/SPECS/$BUILDNAME.spec"
		fi
	fi

	if [ -n "$MAKESPKG" ] ; then
		BUILTRPM=$BUILDERHOME/RPM/SRPMS
		CMDBUILD="LANG=C $NICE rpmbph -n -v ~/RPM/SPECS/$BUILDNAME.spec"
	fi

	#CMDREPORT="( LANG=C winelog -c ; cat ~/.rpmmacros ) >~/buildenv.txt"
	CMDAFTERREPORT="( head -n 5 /usr/bin/rpmbph ; cat ~/RPM/SPECS/LOCAL/$BUILDNAME.spec ; echo "-------" ; rpm --showrc ; echo "-----"; cat ~/RPM/BUILD/${BUILDNAME}*/config.log ; cat ~/RPM/BUILD/${BUILDNAME}*/include/config.h ; rpm -qa )  >>~/buildenv.txt"
	#CMDREPORT="echo; cat ~/RPM/SPECS/$BUILDNAME.spec ; echo"
	CMDREPORT="true"

	# TODO: set defattr after each files section
	# awk 'BEGIN{desk=0}{print;if(/^%build/&&desk==0){printf("%s\n\n", text);desk++}}' text="$RECONFT"

        LOGFAILFILE="$BUILDERHOME/RPM/log/$BUILDNAME.log.failed"
	rm -f $LOGFAILFILE
	echo Chrooting as $INTUSER...
	# copy src.rpm into build system and build
	RPMCOMMAND=rpm
	# Use rpm.static if exist (due ALT's src.rpm has too old version)"
	[ -x "$BUILDROOT/usr/bin/rpm.static" ] && RPMCOMMAND=/usr/bin/rpm.static
	$SUDO chroot $BUILDROOT su - $INTUSER -c "umask 002 ; mkdir -p ~/RPM/SRPMS ; $RPMCOMMAND -i ~/tmp/$BUILDNAME.src.rpm ; $CMDREPORT ; subst 's|@ETERREGNUM@|${ETERREGNUM}|g' ~/RPM/SPECS/$BUILDNAME.spec ; $CMDBUILD || touch ~/RPM/log/$BUILDNAME.log.failed ; $CMDAFTERREPORT"

	ELOGFILE=$LLOGDIR/$BUILDNAME.cenv.log
	cat $BUILDERHOME/buildenv.txt | sed -e "s|[0-9A-F]\{4\}-[0-9A-F]\{4\}|XxXX-XxXX|g" >$ELOGFILE

	[ -e "$LOGFAILFILE" ] && { rm -f "$LOGFAILFILE" ; warning "build failed" ; return 1 ; }


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
			$SUDO chroot $BUILDROOT su - $INTUSER -c "cd $INTBUILT; ls -l ; fakeroot alien --scripts --veryverbose --to-$TARGET *${BUILDNAME}*.rpm ; ls -l" || { warning "alien problem"; return 1 ; }
			;;
		"tgz")
			fakeroot alien --veryverbose --to-$TARGET *${BUILDNAME}*.rpm || { warning "alien problem"; return 1 ; }
			;;
		"tar.gz")
			fakeroot alien --veryverbose --to-tgz *${BUILDNAME}*.rpm || { warning "alien problem"; return 1 ; }
			for i in *${BUILDNAME}*.tgz ; do mv $i `basename $i .tgz`.tar.gz ; done
			;;
		*)
			warning "unknown $TARGET" ; return 1;
	esac
	#echo "To del: $TODEL"
	#[ "$TARGET" = "deb" ] && $SUDO chroot $BUILD su - $INTUSER /usr/bin/dpkg -i $INTBUILT/*${BUILDNAME}*.$TARGET
	# uncomment me!
	#rm -f $TODEL
	popd
	echo "fakeroot do not returns correct result"
	return 0
}

