#!/bin/sh

# load common functions, compatible with local and installed script
. `dirname $0`/../share/eterbuild/korinf/common


define_paths()
{
	find $1 -name bin-\* -print
}

define_components()
{
	DIRCONTENTS=`find $1 -maxdepth 1 -print | grep ".sh" | grep -v all`
	for i in $DIRCONTENTS ; do
		basename $i .sh
	done
}

grep_script()
{
	#FIXME: Highlight this with another color
	echo Checking $1
	$PATHTOSCRIPT/$1.sh -c | grep -e OBS -e MISSED | grep -v Legend
}


#start script
KORINFROOTDIR="../"
PRODUCTPATHS=`define_paths $KORINFROOTDIR`

for PATHTOSCRIPT in $PRODUCTPATHS ; do
	COMPONENTS=`define_components $PATHTOSCRIPT`
	for i in $COMPONENTS ; do
		grep_script $i
		echo
	done
done