#!/bin/sh -x
# 2007, 2009 (c) Etersoft http://etersoft.ru
# Author: Vitaly Lipatov <lav@etersoft.ru>
# Author: Yury Fil <yurifil@etersoft.ru>
# GNU Public License

# script for FreeBSD

querypackage()
{
        rpmquery -p --queryformat "%{$2}" $1
}

fatal()
{
	echo $@ >&2
	exit 1
}

COMMAND=$1
INTUSER=$2
RPMBUILDROOT=$3
PACKAGE=$4
SRPMNAME=$5
TARGETPKG=$6


WRKDIR=/var/tmp/korinfer/work-$PACKAGE
RPMDIR=/home/$INTUSER/RPM/RPMS

mkdir -p $WRKDIR/ && cd $WRKDIR || fatal "Can't CD to $WRKDIR"

# copied from eterbuild/functions/rpm
# build binary package list (1st - repo dir, 2st - pkgname)
# algorithm: list all files in PKGDIR, print packages with our source pkg name
get_binpkg_list()
{
	local PKGDIR=$1
	local PKGNAME=$(basename $2)
	find "$PKGDIR" ! -name '*\.src\.rpm' -name '*\.rpm' -execdir \
		rpmquery -p --qf='%{sourcerpm}\t%{name}-%{version}-%{release}.%{arch}.rpm\n' "{}" \; \
		| egrep "^$PKGNAME[[:space:]].*" | cut -f2 | xargs -n1 -I "{}" echo "$PKGDIR/{} "
}

build_bsd()
{
	echo builduser $INTUSER
	RPMBUILDNODEPS="--nodeps"
	#RPMBUILDROOT="/home/$INTUSER/RPM/BUILD/$PACKAGE-$PKGVERSION"
	# FIXME: x86_64 support
	BUILDARCH=i586
	rpmbuild -v --rebuild $RPMBUILDNODEPS --buildroot $RPMBUILDROOT $SRPMNAME --target $BUILDARCH
}

convert_bsd()
{
	[ -n "$RPMBUILDROOT" ] || fatal "RPMBUILDROOT var is empty"
	cd $RPMBUILDROOT
	#get bin package list
	BUILDRPMLIST=$(get_binpkg_list $WRKDIR $SRPMNAME)
	[ -n "$BUILDRPMLIST" ] || fatal "BUILDRPMLIST var is empty"
	echo convertuser $INTUSER
	echo get package fields
	PKGDESCR=`querypackage "$SRPMNAME" DESCRIPTION`
	PKGCOMMENT=`querypackage "$SRPMNAME" SUMMARY`
	# FIXME: get froup Group rpm field
	PKGGROUP=emulators

	rm -rf $WRKDIR/*
	#mkdir pkgfiles && cd pkgfiles || fatal "error with subdir"
	echo "get file hierarchy of"
	echo $BUILDRPMLIST
	for i in $BUILDRPMLIST ; do
		rpm2cpio $i | cpio -dimv || fatal "error with rpm2cpio on $i"
		rm -f $i
	done

	# FIXME: it is broken way to save +FILES in $WRKDIR
	# make +CONTENTS file
	find ./ \! -type d | sed -e "s|^\./||g" | sort > $WRKDIR/+CONTENTS

	#add dirrm in +CONTENTS
	cat $WRKDIR/+CONTENTS | xargs -n 1 dirname | sort -u | \
		grep -v "^bin/$" | grep -v "^include/$" | \
		grep -v "^/etc/rpm$" | grep -v "^/usr/local/bin$" \
			| sed "s|\(.*\)|@dirrm \1|g" >> $WRKDIR/+CONTENTS

	#make +COMMENT and +DESC files
	echo $PKGCOMMENT > $WRKDIR/+COMMENT
	echo $PKGDESCR > $WRKDIR/+DESC

	# create package with the PACKAGE name (not src.rpm name)
	rm -f $WRKDIR/../$TARGETPKG
	ls -l
	# Note: it is value have the full path for -s args
	pkg_create -v -s $WRKDIR -p/ -c $WRKDIR/+COMMENT -d $WRKDIR/+DESC -f $WRKDIR/+CONTENTS $WRKDIR/../$TARGETPKG || fatal "Can't create package"
	cd -
}

install_bsd()
{
	pkg_delete ${PACKAGE}*
	pkg_add ../$TARGETPKG
}

clean_bsd()
{
	echo "Cleaning..."
	rm -rf $WRKDIR
	rm -rf $RPMDIR/../BUILD/${PACKAGE}
}

case $COMMAND in
	"build")
		build_bsd
		;;
	"convert")
		convert_bsd
		;;
	"install")
		install_bsd
		;;
	"clean")
		clean_bsd
		;;
	*)
		fatal "Unknown command $COMMAND"
		;;
esac
