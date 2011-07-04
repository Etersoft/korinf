#!/bin/sh

#script that checks built packages for our products
#usage: ./check_products.sh [-b] SYSLIST [CHECKPROJECT]

# load common functions, compatible with local and installed script
. `dirname $0`/../share/eterbuild/korinf/common


define_paths()
{
# выбираем в KORINFROOTDIR каталоги, содержащие сборочные скрипты
	find $1 -name bin-\* -print | grep -v old | grep -v common
}

define_components()
{
# выбираем файлы .sh в $PATHTOSCRIPT, исключая файлы foo-all.sh, release-check, cabextract
# FIXME: убрать проверку dkms-* для не-Мандрив: например, через переменную ADDITIONALGREPS, заполняемую по необходимости
	DIRCONTENTS=`find $1 -maxdepth 1 -print | grep ".sh" | grep -v all | grep -v release-check`
	#| grep -v cabextract
	#| grep -v dkms-aksparlnx
	#$ADDITIONALGREPS
	for i in $DIRCONTENTS ; do
		basename $i .sh
	done
}

grep_script()
{
	#FIXME: Highlight this with another color
	echo "Checking $1 for $2"
# запускаем сборочные скрипты с параметром -c, выводим строки, содержащие сообщения об устаревших или пропущенных сборках
	$PATHTOSCRIPT/$1.sh $CHECKONLY $2 $3 | grep -e OBS -e MISSED | grep -v Legend | grep -v link | grep -v error || echo "Everything is built"
}


if [ "$1" = "-b" ] ; then
	CHECKONLY=
	shift
else
	CHECKONLY="-c"
fi

#start script
KORINFROOTDIR="../"
CHECKSYSLIST=$1
CHECKVERSION=$2
CHECKPROJECT=$3

if [ -z $CHECKPROJECT ] ; then
    PRODUCTPATHS=`define_paths $KORINFROOTDIR`
else
    PRODUCTPATHS=$KORINFROOTDIR/bin-${CHECKPROJECT}
fi

#if [ -z $CHECKVERSION ] ; then
#	CHECKVERSION='last'
#fi

echo PRODUCTPATHS=$PRODUCTPATHS

for PATHTOSCRIPT in $PRODUCTPATHS ; do
	COMPONENTS=`define_components $PATHTOSCRIPT`
	for i in $COMPONENTS ; do
		grep_script $i $CHECKSYSLIST $CHECKVERSION
		echo
	done
done