#!/bin/sh
# Выводит сообщения о ненайденных вайновским configure библиотеках
#

export WORKDIR=../functions

. $WORKDIR/config.in

WINENUMVERSION=1.0.9-eter38
NAME=/var/ftp/pub/Etersoft/WINE@Etersoft
#VERSION=1.0.9
#LIST=`cat ../lists/rebuild.list.all`
LIST=$DISTR_LIST

echo $0
for n in $LIST ; do
	echo
	FILE=$NAME/$WINENUMVERSION/WINE/$n/log/wine.log.bz2
	echo "$n: (`stat -c "%y" $FILE`)"
	bzcat $FILE | grep "configure:" | grep development | grep found | sed -e "s|^configure:|          |g"
done
