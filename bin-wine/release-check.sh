#!/bin/sh
RELEASEVERSION=last

if [ -n "$1" ] ; then
	DISTR=$1
	OPT="-q"
else
	DISTR=""
	OPT=""
fi

./wine-etersoft.sh -c $DISTR $RELEASEVERSION
./wine-etersoft-all.sh $OPT -c $DISTR $RELEASEVERSION
./haspd.sh $OPT -c $DISTR $RELEASEVERSION
./fonts-ttf-ms.sh $OPT -c $DISTR $RELEASEVERSION
./fonts-ttf-liberation.sh $OPT -c $DISTR $RELEASEVERSION
