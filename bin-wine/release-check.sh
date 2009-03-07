#!/bin/sh

# Script for check WINE@Etersoft release integrity
# Params:
# ./release-check.sh -b DISTRO  build all packages for the DISTRO
# ./release-check.sh DISTRO     print checks only for the DISTRO
# ./release-check.sh            print overall check info for all distros

RELEASEVERSION=last

if [ "$1" = "-b" ] && [ -n "$2" ] ; then
	CHECKONLY=
	shift
else
	CHECKONLY="-c"
fi

if [ -n "$1" ] ; then
	DISTR=$1
	OPT="-q"
else
	DISTR=""
	OPT=""
fi

./wine-etersoft.sh $CHECKONLY $DISTR $RELEASEVERSION
./wine-etersoft-all.sh $OPT $CHECKONLY $DISTR $RELEASEVERSION
./haspd.sh $OPT $CHECKONLY $DISTR $RELEASEVERSION
./fonts-ttf-ms.sh $OPT $CHECKONLY $DISTR $RELEASEVERSION
./fonts-ttf-liberation.sh $OPT $CHECKONLY $DISTR $RELEASEVERSION
