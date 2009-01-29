#!/bin/sh
# 2008 Vitaly Lipatov (Etersoft)
# script for install new build in the chroot
# run with version public_rel private_rel
# example: install.sh 1.0.9 eter35 eter13

if [ -n "$4" ] ; then
    BRANCH=$1
    shift
fi

VERSION=$1
PUBREL=$2
PRIVREL=$3

if [ -z "$VERSION" ] || [ -z "$PUBREL" ] || [ -z "$PRIVREL" ] ; then
    echo "Usage example:  install.sh [branch] 1.0.9 alt35 alt13"
    echo "   branch - unstable, testing"
    exit 1
fi

ROOTDIR=/net/legacy/$VERSION-$PUBREL

PROJECTNAME=WINE@Etersoft

# Каталог с деревом пакетов свободного WINE и файлов к нему
WINEPUB_PATH=/var/ftp/pub/Etersoft/$PROJECTNAME

# Каталог с закрытой частью
WINEETER_PATH=/var/ftp/pvt/Etersoft/$PROJECTNAME


SYSTEM=ALTLinux/Sisyphus

if [ -n "$BRANCH" ] ; then
    DIRPUB=$BRANCH
else
    DIRPUB=$VERSION
fi
DIRPVT=$VERSION
CUR_PATH_PUB=$DIRPUB/WINE/$SYSTEM


PACKAGENAME=wine-etersoft
RPMLIST="$WINEPUB_PATH/$CUR_PATH_PUB/$PACKAGENAME-$VERSION-$PUBREL.i586.rpm
    $WINEPUB_PATH/$CUR_PATH_PUB/lib$PACKAGENAME-$VERSION-$PUBREL.i586.rpm
    $WINEETER_PATH/$DIRPVT/WINE-SQL/$SYSTEM/$PACKAGENAME-sql-$VERSION-$PRIVREL.i586.rpm"

for i in $RPMLIST ; do
    test -r "$i" && continue
    echo "Package $i is missed"
    exit 1
done

if [ -d $ROOTDIR/var/lib ] ; then
    echo "$ROOTDIR already exists. Check it first."
    exit 1
fi

mkdir -p $ROOTDIR/var/lib/rpm || exit 1
rpm --root $ROOTDIR --initdb || exit 1
rpm --root $ROOTDIR -ivh $RPMLIST --nodeps --noscripts || exit 1

rm -f $VERSION
ln -s $VERSION-$PUBREL $VERSION
