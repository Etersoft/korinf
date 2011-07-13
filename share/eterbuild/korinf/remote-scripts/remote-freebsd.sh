#!/bin/sh -x
# 2007, 2009 (c) Etersoft http://etersoft.ru
# Author: Vitaly Lipatov <lav@etersoft.ru>
# Author: Yury Fil <yurifil@etersoft.ru>
# GNU Public License

# script for FreeBSD

querypackage()
{
        rpm -q -p --queryformat "%{$2}" $1
}

fatal()
{
	echo $@ >&2
	exit 1
}

if [ "$1" = "--internal" ] ; then
	INTUSER=$2
	shift 2
	exec sudo su - $INTUSER $0 $@
fi


COMMAND=$1
INTUSER=$2
RPMDIR=$3
PACKAGE=$4
PACKAGEVERSION=$5
SRPMNAME=$6
TARGETPKG=$7

WRKDIR=/var/tmp/korinfer/work-$PACKAGE
RPMSDIR=$RPMDIR/RPMS
RPMBUILDROOT=$RPMDIR/BUILD/$PACKAGE-$PACKAGEVERSION
#TARGETPKG=$PACKAGE-$PACKAGEVERSION

mkdir -p $WRKDIR/ && cd $WRKDIR || fatal "Can't CD to $WRKDIR"
mkdir -p $RPMSDIR $RPMDIR/BUILD

# copied from eterbuild/functions/rpm
# build binary package list (1st - repo dir, 2st - pkgname)
# algorithm: list all files in PKGDIR, print packages with our source pkg name
get_binpkg_list()
{
	local PKGDIR=$1
	local PKGNAME=$(basename $2)
	find "$PKGDIR" ! -name '*\.src\.rpm' -name '*\.rpm' -execdir \
		rpm -q -p --qf='%{sourcerpm}\t%{name}-%{version}-%{release}.%{arch}.rpm\n' "{}" \; \
		| egrep "^$PKGNAME[[:space:]].*" | cut -f2 | xargs -n1 -I "{}" echo "$PKGDIR/{} "
}

build_bsd()
{
	RPMBUILDNODEPS="--nodeps"
#	RPMBUILDROOT="/home/$INTUSER/RPM/BUILD/$PACKAGE-$PKGVERSION"
	echo $RPMBUILDROOT
	rm -rf $RPMBUILDROOT/*
	# FIXME from Lav: What the hardcoded path??
	rm -rf /usr/local/share/etercifs/sources/*$PACKAGE*
	# FIXME: x86_64 support
	BUILDARCH=i586
	rpm -v --rebuild $RPMBUILDNODEPS $SRPMNAME --target $BUILDARCH
}

convert_bsd()
{
# FIXME from Lav: we need get package arch from package
# remove this after find out, why built rpm is put into /usr/local/src/portbld/RPMS
	#echo $BUILTRPM
	#| grep '.rpm'
	BUILTRPM=$(echo $RPMSDIR/noarch/*$PACKAGE*.rpm)
	#BUILTRPM=`find $RPMSDIR -name $PACKAGE*.rpm -print | xargs echo`
	if [ ! -r "$BUILTRPM" ] ; then
		BUILTRPM=$(echo $RPMSDIR/i586/*$PACKAGE*.rpm)
		#ARCH=i586
		#BUILTRPM=$(echo /usr/local/src/portbld/RPMS/$ARCH/$PACKAGE*.rpm)
	fi
	#ls -l $BUILTRPM
	[ -n "$BUILTRPM" ] || fatal "BUILTRPM not found"
	#cd $RPMBUILDROOT
	
#end of hack

	#echo $BUILTRPM
	mv $BUILTRPM $RPMSDIR
	#ls -l $RPMSDIR | grep $PACKAGE

	#get bin package list
#	BUILDRPMLIST=$(get_binpkg_list $WRKDIR $SRPMNAME)
	BUILDRPMLIST=$(get_binpkg_list $RPMSDIR $SRPMNAME)
	[ -n "$BUILDRPMLIST" ] || fatal "BUILDRPMLIST var is empty"

	#get package fields
	PKGDESCR=`querypackage "$SRPMNAME" DESCRIPTION`
	PKGCOMMENT=`querypackage "$SRPMNAME" SUMMARY`

	# FIXME: get froup Group rpm field
	PKGGROUP=emulators

	rm -rf $WRKDIR/*

	#mkdir pkgfiles && cd pkgfiles || fatal "error with subdir"
	echo "get file hierarchy of $BUILDRPMLIST"
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
	pkg_create -v -s $WRKDIR -p/ -c $WRKDIR/+COMMENT -d $WRKDIR/+DESC -f $WRKDIR/+CONTENTS $WRKDIR/$TARGETPKG || fatal "Can't create package"
	cd -
}

install_bsd()
{
	PACKAGEDEL=$(pkg_info -x $PACKAGE | grep $PACKAGE | sed -e "s/.*\($PACKAGE-.*\):/\1/g")
	pkg_delete $PACKAGEDEL
	pkg_add $WRKDIR/$TARGETPKG
}

clean_bsd()
{
	echo "Cleaning..."
	rm -rf $WRKDIR
	rm -rf $RPMSDIR/../BUILD/${PACKAGE}
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
