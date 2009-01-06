#!/bin/sh
# 2005, 2006, 2007 (c) Etersoft http://etersoft.ru
# Author: Daniil Kruchinin <asgard@etersoft.ru>
# Author: Vitaly Lipatov <lav@etersoft.ru>
# GNU Public License

# Internal build script for FreeBSD
# positional parameters
COMMAND="$1"
PACKAGE="$2"
WINENUMVERSION="$3"
PRODUCT="$4"
ETERREGNUM="$5"
SOURCEURL="$6"

umask 0002
UID=`id -u`

echo "Start with PACKAGE: $PACKAGE WINENUMVERSION: $WINENUMVERSION PRODUCT: $PRODUCT ETERREGNUM: $ETERREGNUM, command - $COMMAND, sourceurl - $SOURCEURL"
[ -n "$PRODUCT" ] && EPACKAGE=$PACKAGE-$PRODUCT || EPACKAGE=$PACKAGE


cd `dirname $0`

TPL="$PACKAGE-\d*"
if [ "$PACKAGE" = "wine-etersoft" ]; then
	TPL="$PACKAGE-.*\.[network|local|sql]"
fi

if [ "$COMMAND" = "clean" ] ; then
	rm -rf `dirname $0`
#	echo "ok, cleaning...."
	exit 0
fi

if [ "$COMMAND" = "install" ] ; then
	#  WINENUMVERSION=$WINENUMVERSION 
#	echo "Trying to cd into `pwd`/`find . -type d -depth 1 -name "$EPACKAGE*"`"
	cd /usr/ports/packages/All
#	cd `find . -type d -depth 1 -name "$EPACKAGE*"` || exit $?
	make deinstall
	pkg_add *.tbz || exit $?
	exit 0
fi



#echo "My current directory is `pwd`, with `ls`"
echo "I'm in FreeBSD. My current id is `whoami`, removing $TPL package"
# зачем удаляем пакет сначала?
# удалять не надо. надо выставить FORCE_PKG_REGISTER=yes
# удалять надо! иначе пакуется несколько раз.
#pkg_info -x $TPL && pkg_delete -xf $TPL
pkg_delete -xf "$EPACKAGE"

# вот здесь конфликт по файлам...
# Удаляем все пакеты начинающиеся с wine
rm -rf /usr/ports/distfiles/$PACKAGE* /usr/ports/distfiles/$PACKAGE* /usr/ports/packages/All/$PACKAGE*

portfiles="$SOURCEURL/freebsd-$EPACKAGE.tar.bz2"
echo "Fetching port from $portfiles..."
fetch $portfiles > /dev/null || exit $?
echo "Extracting port tarball freebsd-$EPACKAGE.tar.bz2..."
tar xjvf freebsd-$EPACKAGE.tar.bz2 > /dev/null || exit $?
#find ./ -type d -name "${PACKAGE}*"
#echo "Current directory is `pwd`"
#echo "Looking into it: `ls`"
echo "Trying to cd into `pwd`/`find . -type d -depth 1 -name "$EPACKAGE*"`"
cd `find . -type d -depth 1 -name "$EPACKAGE*"` || exit $?
	
export WINENUMVERSION
mv pkg-descr pkg-in
sed -e "s/XXXX-XXXX/$ETERREGNUM/" <pkg-in >pkg-descr
#echo && echo && echo $WINENUMVERSION && echo && echo
make makesum || exit $?
env ETERREGNUM=$ETERREGNUM make package || exit $?
