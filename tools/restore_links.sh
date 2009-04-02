#!/bin/sh

# load common functions, compatible with local and installed script
. `dirname $0`/../share/eterbuild/korinf/common

# Etalon path
PATHTO=$WINEPUB_PATH/1.0.10/WINE

PATHNEW=$1

for i in $(get_distro_list $PATHTO/../); do
#for i in ASPLinux/11.2 ; do
	LI=
	if [ -L $PATHTO/$i ] ; then
		LI=`readlink $PATHTO/$i | sed -e "s|\.\./||g;s|/| |g"`
		RL=`readlink $PATHTO/$i`
		if [ ! -L "$PATHNEW/$i" ] ; then
			echo Create link at $PATHNEW/$i
			mkdir -p `dirname $PATHNEW/$i`
			rm -rf $PATHNEW/$i
			ln -s $RL $PATHNEW/$i
		fi
	fi
	echo "i: $i LI: $LI RL: `readlink $PATHTO/$i` -- `dirname $PATHNEW/$i`"

done
