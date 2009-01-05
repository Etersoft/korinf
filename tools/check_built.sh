#!/bin/sh
# 2006 (c) Etersoft www.etersoft.ru
# Public domain

WINEM=WINE-SQL
OUSER=test
# disable other side test
if false ; then
#if [ ! `id -un` = "$OUSER" ] ; then
	echo
	echo "Restart script with $OUSER user"
	echo "`realpath $0` $1"
	sudo su - $OUSER -c "`realpath $0` $1"
	exit 0
fi

#. /etc/rpm/etersoft-build-functions

export WORKDIR=../functions

. $WORKDIR/config.in

#[ "$1" = "-c" ] && ALPHA=-current
test -z "$ALPHA" && ALPHA=/current
[ "$1" = "-r" ] && ALPHA=/$WINENUMVERSION

# Note: list for released version only
#echo "List: $DISTR_LIST"
check_file()
{
if [ ! -d "$PATHTO" ] ; then
	echo "Path $PATHTO is missed"
	exit 1
fi
for i in $DISTR_LIST ; do
	NAME=$i
	test -L $PATHTO/$i && NAME="$NAME [L]"
	FILENAME=$(ls -1 $PATHTO/$i/${CHECKFILE}* | sort -n | head -n1)
	#echo $FILENAME
	if [ -r "$FILENAME" ] ; then
		FILEDATE=`stat -c"%y" $FILENAME | sed -e "s|\..*$||"`
		FILESIZE=`stat -c"%s" $FILENAME`
		BASENAME=`basename $FILENAME`
	else
		FILEDATE="MISSED"
		FILESIZE=""
		BASENAME=$NAME
	fi
	printf "%22s: %20s  %7s  %s" "$NAME" "$FILEDATE" "$FILESIZE" "$BASENAME"
	test -L $PATHTO/$i && echo -n " (link to `readlink $PATHTO/$i`)"
	echo
	#echo $FILEDATE |
done
}

echo
echo -n "Product: $WINEVERSION. Check for date `date`"
echo
WINEVER=$WINENUMVERSION
CHECKFILE="wine[-_]*${WINEVER}"
PATHTO=$WINEPUB_PATH$ALPHA/WINE
echo
echo "Check for $CHECKFILE... in $PATHTO"
check_file

CHECKFILE="wine[-_]etersoft"
PATHTO=$WINEETER_PATH$ALPHA/$WINEM
echo
echo "Check for $CHECKFILE... in $PATHTO"
check_file

CHECKFILE="haspd[-_]2"
PATHTO=$WINEPUB_PATH$ALPHA/WINE
echo
echo "Check for $CHECKFILE... in $PATHTO"
check_file

CHECKFILE="fonts-ttf-ms[-_]"
PATHTO=$WINEPUB_PATH$ALPHA/fonts
echo
echo "Check for $CHECKFILE... in $PATHTO"
check_file

CHECKFILE="fonts-ttf-liberation[-_]"
PATHTO=$WINEPUB_PATH$ALPHA/WINE
echo
echo "Check for $CHECKFILE... in $PATHTO"
check_file

CHECKFILE="etercifs[-_]"
PATHTO=$WINEPUB_PATH$ALPHA/CIFS
echo
echo "Check for $CHECKFILE... in $PATHTO"
check_file

PATHTO=$WINEPUB_PATH$ALPHA/../../PostgreSQL/8.2
CHECKFILE="*icu[-_]"
echo
echo "Check for $CHECKFILE... in $PATHTO"
check_file

CHECKFILE="postgresql8.3.5eter[-_]"
echo
echo "Check for $CHECKFILE... in $PATHTO"
check_file
