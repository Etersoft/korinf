#!/bin/sh

# Запустить для подготовки релиза к публикации наружу

if [ "$1" = "--makemd5" ] ; then
	shift
	test -L "$1" && exit 0
	cd "$1" || exit 1
	#pwd
	find ./ -type f -maxdepth 1 -name "*.*" -print0 | xargs -0 --no-run-if-empty md5sum | sed -e "s|\./||g" >MD5SUM
	test -s MD5SUM || rm -f MD5SUM
	exit 0
fi

cd `dirname $0`/..
WORKDIR=`pwd`

. /etc/rpm/etersoft-build-functions

. functions/config.in || fatal "Can't locate config.in"

check_key

PATHTO=$WINEPUB_PATH-$WINENUMVERSION

# Make distro list
LISTFILE=$PATHTO/docs/distro.list
>$LISTFILE
for i in $DISTR_LIST ; do
	
	echo $i | grep -v Special | grep -v Windows >>$LISTFILE
done

# Добавить проверку пакетов

find $PATHTO -name "*.rpm" ! -type l -print0 | xargs -0 rpm --addsign
#exit 1
#find $WINEETER_PATH$ALPHA-{Local,Network} -name "*.rpm" | xargs rpm --addsign


sudo chmod o-w -R $PATHTO
sudo chmod o+r -R $PATHTO
sudo chmod a+rX -R $WINEETER_PATH-$WINENUMVERSION

cd $PATHTO
echo -n "Check what we publishing from..."
find ./ -type f | grep -v public | grep -i wine-etersoft && fatal "DO NOT PUBLISH Etersoft's proprietary"
echo
cd -

#for i in $PATHTO $WINEETER_PATH-$WINENUMVERSION ; do
for i in $PATHTO ; do
	cd $i
	# TODO: в скрипт публикации
	#echo -n "Make md5sum in $i..."
	#find -L ./ -type d -print0 | xargs -n1 -0 $WORKDIR/tools/prepare_release.sh --makemd5
	#clamscan ./ -r || exit 1
	cd -
done

#exit 1
# Note: we exclude tarballs
# TODO: --links не работает?
 