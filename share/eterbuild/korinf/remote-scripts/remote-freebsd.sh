#!/bin/sh
# 2007 (c) Etersoft http://etersoft.ru
# Author: Vitaly Lipatov <lav@etersoft.ru>
# GNU Public License

# script for FreeBSD

#testing



querypackage()
{
        rpmquery -p --queryformat "%{$2}" $1
}

make_plist()
{
}

NAME=$1
PKGVERSION=$5
i=$NAME*

WRKDIR=/var/tmp/korinf/work-$NAME/
RPMDIR=/home/builder/RPM/RPMS

#unpack rpm and set variables
mkdir $WRKDIR
#test
cp $RPMDIR/$i.rpm $WRKDIR

cd $WRKDIR
PACKAGENAME=`querypackage "$i" NAME`
PKGVERSION=`querypackage "$i" VERSION`
PKGREL=`querypackage "$i" RELEASE`
PKGDESCR=`querypackage "$i" DESCRIPTION`
PKGCOMMENT=`querypackage "$i" SUMMARY`
PKGGROUP=emulators

#get file hierarchy
rpm2cpio $i | cpio -dimv #$PACKAGENAME.cpio | tar cjvf $PACKAGENAME.tar.bz2
rm -f *.rpm

#make +CONTENTS file
find -d * \! -type d | sort >> $WRKDIR/files
echo '@cwd /usr/local' > $WRKDIR/+CONTENTS
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

#create package
pkg_create -s $WRKDIR -c $WRKDIR/+COMMENT -d $WRKDIR/+DESC -f $WRKDIR/+CONTENTS $PACKAGENAME.tbz

#end of testing
