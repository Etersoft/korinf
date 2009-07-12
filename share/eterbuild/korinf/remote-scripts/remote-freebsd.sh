#!/bin/sh
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
PACKAGE=$2
# build
SRPMNAME=$3
# convert
RELPKG=$3

WRKDIR=/var/tmp/korinf/work-$PACKAGE/
RPMDIR=/home/builder/RPM/RPMS

mkdir -p $WRKDIR/ && cd $WRKDIR || fatal "Can't CD to $WRKDIR"

build_bsd()
{
	RPMBUILDNODEPS="--nodeps"
	RPMBUILDROOT="~/tmp/$PACKAGE-buildroot"
	# FIXME: x86_64 support
	BUILDARCH=i586
	rpmbuild -v --rebuild $RPMBUILDNODEPS --buildroot $RPMBUILDROOT ~/tmp/$SRPMNAME --target $BUILDARCH
}

convert_bsd()
{
	# FIXME: how to get build package name?
	#PKGNAME=`querypackage "$SRPMNAME" NAME`
	PKGNAME=""
	BUILTRPM=$(ls -1 $RPMDIR/RPMS | grep $PKGNAME | tail -n1)

PKGVERSION=`querypackage "$BUILTRPM" VERSION`
PKGREL=`querypackage "$BUILTRPM" RELEASE`
PKGDESCR=`querypackage "$BUILTRPM" DESCRIPTION`
PKGCOMMENT=`querypackage "$BUILTRPM" SUMMARY`
PKGGROUP=emulators

echo
echo variables:
echo $SRPMNAME
echo $BUILTRPM
echo $PKGVERSION
echo $PKGREL
echo

#get file hierarchy
rpm2cpio $BUILTRPM | cpio -dimv || fatal "error with rpm2cpio"
rm -f $BUILTRPM

#make +CONTENTS file
find -d * \! -type d | sort >> $WRKDIR/files
#set the internal directory pointer to /usr/local/
#echo '@cwd /usr/local' > $WRKDIR/+CONTENTS
cat $WRKDIR/files >> $WRKDIR/+CONTENTS
rm -f $WRKDIR/files

#add dirrm in +CONTENTS
cat $WRKDIR/+CONTENTS | xargs -n 1 dirname | sort -u | grep -v "^bin/$" | grep -v "^include/$" > $WRKDIR/dirs
cat $WRKDIR/dirs | sed "s|\(.*\)|@dirrm \1|g" >> $WRKDIR/+CONTENTS
rm -f $WRKDIR/dirs

#make +COMMENT and +DESC files
echo $PKGCOMMENT > $WRKDIR/+COMMENT
echo $PKGDESCR > $WRKDIR/+DESC

cd ..
#$PKGPLIST>\+CONTENTS

# create package with the PACKAGE name (not src.rpm name)
pkg_create -s $WRKDIR -c $WRKDIR/+COMMENT -d $WRKDIR/+DESC -f $WRKDIR/+CONTENTS ${PACKAGE}-${RELPKG}.tbz || fatal
}

case $COMMAND in
	"build")
		build_bsd()
		;;
	"convert")
		convert_bsd()
		;;
	"install")
		instal_bsd()
		;;
	"clean")
		clean_bsd()
		;;
	*)
		fatal "Unknown command $COMMAND"
		;;
esac
