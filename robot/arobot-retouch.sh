#!/bin/sh

# Ставит провалившиеся задания опять на сборку

DIRNAME=`dirname $0`
[ "$DIRNAME" = "." ] && DIRNAME=`pwd`
cd $DIRNAME/..

. functions/helpers.sh
ALOGDIR=$ALOGDIR-arobot

switch_to_builder $DIRNAME/`basename $0`

#pwd
cd ~/sales
#ls -l
#exit 1

if [ -z "$1" ] ; then
	for i in *.failed ; do
		test -f $i || continue
		mv -v $i `basename $i .failed` || exit 1
	done
else
	for i in *.broken ; do
		test -f $i || continue
		mv -v $i `basename $i .broken` || exit 1
	done
fi
cd -

