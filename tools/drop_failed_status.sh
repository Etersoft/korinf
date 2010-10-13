#!/bin/sh
# Выводит сообщения о ненайденных вайновским configure библиотеках
#

# load common functions, compatible with local and installed script
. `dirname $0`/../share/eterbuild/korinf/common


FTPPATH=/var/ftp/pub/Etersoft
PRODLIST="CIFS@Etersoft/* HASP/* Postgres@Etersoft/* RX@Etersoft/* WINE@Etersoft/*/WINE WINE@Etersoft/*/fonts Wine-public/* Wine-vanilla/*"

for p in $PRODLIST ; do
	VERLIST=$(echo $FTPPATH/$p)
	for v in $VERLIST ; do
		echo "Prodversion: $v"
		#for n in $(get_distro_list $v) ; do
		for n in $v/x86_64/*/* $v/*/* ; do
			#echo "$p - $v - $n"
			rm -vf $n/log/*.build.failed
			#echo "$n: (`stat -c "%y" $FILE`)"
			#bzcat $FILE | grep "configure:" | grep development | grep found | sed -e "s|^configure:|          |g"
		done
	done
done
