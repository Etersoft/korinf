#!/bin/sh
# 2005, 2006, 2007 (c) Etersoft http://etersoft.ru
# Author: Daniil Kruchinin <asgard@etersoft.ru>
# Author: Vitaly Lipatov <lav@etersoft.ru>
# GNU Public License

# Internal build script for FreeBSD
# positional parameters
COMMAND="$1"
PACKAGE="$2"
ETERREGNUM="$3"
SOURCEURL="$4"
export PACKAGEVERSION="$5"

umask 0002
UID=`id -u`

echo "Start with PACKAGE: $PACKAGE ETERREGNUM: $ETERREGNUM, command - $COMMAND, sourceurl - $SOURCEURL, version - $PACKAGEVERSION"


cd `dirname $0`

TPL="$PACKAGE-\d*"

if [ "$COMMAND" = "clean" ] ; then
	rm -rf `dirname $0`
#	echo "ok, cleaning...."
	exit 0
fi

if [ "$COMMAND" = "install" ] ; then
#	echo "Trying to cd into `pwd`/`find . -type d -depth 1 -name "$PACKAGE*"`"
	cd /usr/ports/packages/All
#	cd `find . -type d -depth 1 -name "$PACKAGE*"` || exit $?
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
pkg_delete -xf "$PACKAGE"

# вот здесь конфликт по файлам...
# Удаляем все пакеты начинающиеся с wine
rm -rf /usr/ports/distfiles/$PACKAGE* /usr/ports/distfiles/$PACKAGE* /usr/ports/packages/All/$PACKAGE*

portfiles="$SOURCEURL/freebsd-$PACKAGE.tar.bz2"
echo "Fetching port from $portfiles..."
fetch $portfiles > /dev/null || exit $?
echo "Extracting port tarball freebsd-$PACKAGE.tar.bz2..."
tar xjvf freebsd-$PACKAGE.tar.bz2 > /dev/null || exit $?
#find ./ -type d -name "${PACKAGE}*"
#echo "Current directory is `pwd`"
#echo "Looking into it: `ls`"
echo "Trying to cd into `pwd`/`find . -type d -depth 1 -name "$PACKAGE*"`"
cd `find . -type d -depth 1 -name "$PACKAGE*"` || exit $?
	
mv pkg-descr pkg-in
sed -e "s/XXXX-XXXX/$ETERREGNUM/" <pkg-in >pkg-descr
make makesum || exit $?
env ETERREGNUM=$ETERREGNUM make package || exit $?
